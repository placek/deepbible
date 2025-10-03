module App.Component where

import Prelude

import App.Util (encodeURIComponent)
import Affjax as AX
import Affjax.ResponseFormat as ResponseFormat
import Data.Argonaut.Decode (class DecodeJson, decodeJson, (.:?))
import Data.Array (deleteAt, filter, find, findIndex, index, length, snoc)
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..), fromMaybe, maybe)
import Data.String as String
import Data.Traversable (for)
import Data.Tuple (Tuple(..))
import Effect.Aff (Aff)
import Effect.Class (class MonadEffect)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP

data Source = Source
  { id :: String
  , language :: String
  , source_number :: Int
  , name :: String
  , description_short :: Maybe String
  }

derive instance eqSource :: Eq Source

instance decodeSource :: DecodeJson Source where
  decodeJson json = do
    obj <- decodeJson json
    id <- obj .:? "id"
    language <- obj .:? "language"
    source_number <- obj .:? "source_number"
    name <- obj .:? "name"
    description_short <- obj .:? "description_short"
    pure $ Source { id, language, source_number, name, description_short }

data Verse = Verse
  { book_number :: Int
  , chapter :: Int
  , verse :: Int
  , verse_id :: String
  , language :: String
  , source :: String
  , address :: String
  , text :: String
  }

derive instance eqVerse :: Eq Verse

derive instance ordVerse :: Ord Verse

instance decodeVerse :: DecodeJson Verse where
  decodeJson json = do
    obj <- decodeJson json
    book_number <- obj .:? "book_number"
    chapter <- obj .:? "chapter"
    verse <- obj .:? "verse"
    verse_id <- obj .:? "verse_id"
    language <- obj .:? "language"
    source <- obj .:? "source"
    address <- obj .:? "address"
    text <- obj .:? "text"
    pure $ Verse { book_number, chapter, verse, verse_id, language, source, address, text }


type AddressResult =
  { address :: String
  , verses :: Array TranslationColumn
  }

type TranslationColumn =
  { source :: Source
  , verses :: Array Verse
  }

type State =
  { addressesInput :: String
  , parsedAddresses :: Array String
  , baseUrl :: String
  , availableSources :: Array Source
  , selectedSources :: Array Source
  , results :: Array AddressResult
  , loading :: Boolean
  , error :: Maybe String
  }

data Action
  = Initialize
  | SetBaseUrl String
  | UpdateAddresses String
  | AddSource String
  | RemoveSource String
  | MoveSourceUp String
  | MoveSourceDown String
  | RequestVerses
  | ReceiveSources (Either String (Array Source))
  | ReceiveVerses (Either String (Array AddressResult))

component :: forall query input output m. MonadEffect m => H.Component query input output m
component = H.mkComponent
  { initialState: const initialState
  , render
  , eval: H.mkEval $ H.defaultEval
      { initialize = Just Initialize
      , handleAction = handleAction
      }
  }

initialState :: State
initialState =
  { addressesInput: ""
  , parsedAddresses: []
  , baseUrl: "http://localhost:3000"
  , availableSources: []
  , selectedSources: []
  , results: []
  , loading: false
  , error: Nothing
  }

handleAction :: forall output m. MonadEffect m => Action -> H.HalogenM State Action () output m Unit
handleAction = case _ of
  Initialize -> do
    st <- H.get
    H.modify_ (_ { loading = true, error = Nothing })
    result <- H.liftAff (fetchSources st.baseUrl)
    handleAction (ReceiveSources result)
  SetBaseUrl url ->
    H.modify_ (_ { baseUrl = url })
  UpdateAddresses text ->
    H.modify_ (_ { addressesInput = text })
  AddSource sourceId -> do
    st <- H.get
    case find (matches sourceId) st.availableSources of
      Nothing -> pure unit
      Just src -> do
        let remaining = Array.filter (not <<< matches sourceId) st.availableSources
            selected = st.selectedSources `snoc` src
        H.put st { availableSources = remaining, selectedSources = selected }
  RemoveSource sourceId -> do
    st <- H.get
    let selected = Array.filter (not <<< matches sourceId) st.selectedSources
        removed = Array.filter (matches sourceId) st.selectedSources
        available = sortSources (st.availableSources <> removed)
    H.put st { availableSources = available, selectedSources = selected }
  MoveSourceUp sourceId ->
    H.modify_ (_ { selectedSources = shift (-1) sourceId })
  MoveSourceDown sourceId ->
    H.modify_ (_ { selectedSources = shift 1 sourceId })
  RequestVerses -> do
    st <- H.get
    let addresses = parseAddresses st.addressesInput
    if Array.null addresses || Array.null st.selectedSources then
      H.modify_ (_ { error = Just "Type at least one address and choose at least one translation." })
    else do
      H.put st { loading = true, parsedAddresses = addresses, error = Nothing }
      result <- H.liftAff (fetchVerses st.baseUrl addresses st.selectedSources)
      handleAction (ReceiveVerses result)
  ReceiveSources (Left err) ->
    H.modify_ (_ { loading = false, error = Just err })
  ReceiveSources (Right sources) ->
    H.modify_ (_ { loading = false, availableSources = sortSources sources })
  ReceiveVerses (Left err) ->
    H.modify_ (_ { loading = false, error = Just err })
  ReceiveVerses (Right results) ->
    H.modify_ (_ { loading = false, results = results })
  where
  matches sourceId (Source s) = s.id == sourceId

  shift delta sourceId sources =
    case findIndex (matches sourceId) sources of
      Nothing -> sources
      Just idx ->
        let newIndex = clamp 0 (length sources - 1) (idx + delta)
        in if newIndex == idx then sources else
          fromMaybe sources do
            without <- deleteAt idx sources
            item <- index sources idx
            Array.insertAt newIndex item without

  clamp lo hi value = max lo (min hi value)

fetchSources :: String -> Aff (Either String (Array Source))
fetchSources baseUrl = do
  let request = AX.defaultRequest
        { url = baseUrl <> "/_all_sources"
        , responseFormat = ResponseFormat.json
        }
  response <- AX.request request
  pure case response.response of
    Nothing -> Left "Unable to decode sources response"
    Just json ->
      case decodeJson json of
        Left err -> Left (show err)
        Right sources -> Right sources

fetchVerses :: String -> Array String -> Array Source -> Aff (Either String (Array AddressResult))
fetchVerses baseUrl addresses sources = do
  results <- for addresses \address -> do
    columns <- for sources \src@(Source s) -> do
      verses <- requestVerses baseUrl address (Just s.language) (Just s.name)
      pure { source: src, verses }
    pure { address, verses: columns }
  pure (Right results)

requestVerses :: String -> String -> Maybe String -> Maybe String -> Aff (Array Verse)
requestVerses baseUrl address language source = do
  let query = baseUrl <> "/rpc/verses_by_address?p_address=" <> encodeURIComponent address
        <> maybe "" (\lang -> "&p_language=" <> encodeURIComponent lang) language
        <> maybe "" (\src -> "&p_source=" <> encodeURIComponent src) source
      request = AX.defaultRequest
        { url = query
        , responseFormat = ResponseFormat.json
        }
  response <- AX.request request
  case response.response of
    Nothing -> pure []
    Just json ->
      case decodeJson json of
        Left _ -> pure []
        Right verses -> pure verses

parseAddresses :: String -> Array String
parseAddresses text =
  Array.filter (not <<< String.null)
    (Array.map String.trim (String.split (String.Pattern ";") text))

sortSources :: Array Source -> Array Source
sortSources = Array.sortWith (\(Source s) -> Tuple s.language s.name)

render :: forall m. State -> H.ComponentHTML Action () m
render state =
  HH.div [ HP.class_ $ H.ClassName "app" ]
    [ HH.div [ HP.class_ $ H.ClassName "sidebar" ]
        [ HH.h1_ [ HH.text "DeepBible verses" ]
        , HH.div [ HP.class_ $ H.ClassName "control" ]
            [ HH.label_
                [ HH.span_ [ HH.text "PostgREST URL" ]
                , HH.input
                    [ HP.type_ HP.InputText
                    , HP.value state.baseUrl
                    , HE.onValueInput SetBaseUrl
                    ]
                ]
            ]
        , HH.div [ HP.class_ $ H.ClassName "control" ]
            [ HH.label_
                [ HH.span_ [ HH.text "Addresses" ]
                , HH.textarea
                    [ HP.rows 4
                    , HP.value state.addressesInput
                    , HP.placeholder "Genesis 1,1-5; John 3,16"
                    , HE.onValueInput UpdateAddresses
                    ]
                ]
            , HH.button
                [ HP.class_ $ H.ClassName "primary"
                , HE.onClick (const RequestVerses)
                ]
                [ HH.text "Fetch verses" ]
            ]
        , HH.div [ HP.class_ $ H.ClassName "control" ]
            [ HH.h2_ [ HH.text "Translations" ]
            , HH.p_ [ HH.text "Selected order" ]
            , HH.ul_ (map renderSelected state.selectedSources)
            , HH.p_ [ HH.text "Available" ]
            , HH.ul_ (map renderAvailable state.availableSources)
            ]
        , case state.error of
            Nothing -> HH.text ""
            Just err -> HH.p [ HP.class_ $ H.ClassName "error" ] [ HH.text err ]
        ]
    , HH.div [ HP.class_ $ H.ClassName "content" ]
        [ if state.loading then HH.p_ [ HH.text "Loading..." ] else HH.text ""
        , HH.div_ (map renderAddress state.results)
        ]
    ]
  where
  renderSelected src@(Source s) =
    HH.li [ HP.class_ $ H.ClassName "selected" ]
      [ HH.div [ HP.class_ $ H.ClassName "selected-controls" ]
          [ HH.button [ HE.onClick (const (MoveSourceUp s.id)) ] [ HH.text "↑" ]
          , HH.button [ HE.onClick (const (MoveSourceDown s.id)) ] [ HH.text "↓" ]
          , HH.button [ HE.onClick (const (RemoveSource s.id)) ] [ HH.text "✕" ]
          ]
      , HH.div [ HP.class_ $ H.ClassName "selected-label" ]
          [ HH.span [ HP.class_ $ H.ClassName "language" ] [ HH.text s.language ]
          , HH.span [ HP.class_ $ H.ClassName "name" ] [ HH.text s.name ]
          ]
      ]

  renderAvailable src@(Source s) =
    HH.li [ HP.class_ $ H.ClassName "available" ]
      [ HH.button
          [ HP.class_ $ H.ClassName "ghost"
          , HE.onClick (const (AddSource s.id))
          ]
          [ HH.span [ HP.class_ $ H.ClassName "language" ] [ HH.text s.language ]
          , HH.text " "
          , HH.text s.name
          ]
      , case s.description_short of
          Nothing -> HH.text ""
          Just description -> HH.span [ HP.class_ $ H.ClassName "description" ] [ HH.text description ]
      ]

  renderAddress result =
    HH.section [ HP.class_ $ H.ClassName "address" ]
      [ HH.h2_ [ HH.text result.address ]
      , HH.div [ HP.class_ $ H.ClassName "columns" ] (map renderColumn result.verses)
      ]

  renderColumn { source: Source s, verses } =
    HH.article [ HP.class_ $ H.ClassName "column" ]
      [ HH.header [ HP.class_ $ H.ClassName "column-header" ]
          [ HH.span [ HP.class_ $ H.ClassName "language" ] [ HH.text s.language ]
          , HH.span [ HP.class_ $ H.ClassName "name" ] [ HH.text s.name ]
          ]
      , HH.div [ HP.class_ $ H.ClassName "verse-group" ] (map renderVerse verses)
      ]

  renderVerse (Verse v) =
    HH.div [ HP.class_ $ H.ClassName "verse-line" ]
      [ HH.div [ HP.class_ $ H.ClassName "meta" ]
          [ HH.span [ HP.class_ $ H.ClassName "reference" ] [ HH.text (show v.chapter <> ":" <> show v.verse) ]
          ]
      , HH.div [ HP.class_ $ H.ClassName "text" ]
          [ HH.text v.text ]
      ]
