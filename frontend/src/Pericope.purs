module Pericope (Query(..), Output(..), component) where

import Prelude

import Api (fetchSources, fetchVerses)
import Data.Array (catMaybes)
import Data.Array as A
import Data.Either (Either(..))
import Data.Foldable (intercalate)
import Data.Maybe (Maybe(..))
import Data.Set as Set
import Data.Newtype (unwrap)
import Data.Ord (comparing)
import Web.UIEvent.MouseEvent (MouseEvent, ctrlKey, toEvent)
import Web.HTML.Event.DragEvent (DragEvent)
import Web.HTML.Event.DragEvent as DragEv
import Web.Event.Event (preventDefault, stopPropagation)
import Web.UIEvent.KeyboardEvent (key)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Effect.Aff.Class (class MonadAff)

import Types (Pericope, PericopeId, Verse(..), Address, Source, SourceInfo)

-- Child component for one pericope; it is Controlled by parent via Query/Output

data Query a
  = SetData Pericope a
  | Refresh a

data Output
  = DidDuplicate { id :: PericopeId }
  | DidRemove PericopeId
  | DidStartDrag PericopeId
  | DidDragOver PericopeId
  | DidDragLeave PericopeId
  | DidReorder { from :: PericopeId, to :: PericopeId }
  | DidUpdate Pericope

type State =
  { pericope :: Pericope
  , editingAddress :: Boolean
  , editingSource :: Boolean
  , sources :: Maybe (Array SourceInfo)
  }

component :: forall m. MonadAff m => H.Component Query Pericope Output m
component = H.mkComponent
  { initialState: \p -> { pericope: p, editingAddress: false, editingSource: false, sources: Nothing }
  , render
  , eval: H.mkEval $ H.defaultEval
      { handleAction = handle
      , receive = Just <<< Receive
      }
  }

-- Local actions
data Action
  = Noop
  | HandleAddressClick MouseEvent
  | HandleSourceClick MouseEvent
  | SwallowDidascaliaClick MouseEvent
  | ToggleSelect String -- verse_id
  | SetAddress String
  | SetSource String
  | SubmitAddress
  | SubmitSource
  | SelectSource Source
  | Remove
  | DragStart DragEvent
  | DragOver DragEvent
  | DragLeave DragEvent
  | Drop DragEvent
  | Receive Pericope

render :: forall m. State -> H.ComponentHTML Action () m
render st =
  let
    selectedAddresses =
      catMaybes $ st.pericope.verses <#> \(Verse v) ->
        if Set.member v.verse_id st.pericope.selected then Just v.address else Nothing
    addressText =
      case selectedAddresses of
        [] -> ""
        xs -> intercalate "; " xs
  in
  HH.div [ HP.class_ (HH.ClassName "pericope") ]
    [ HH.div
        [ HP.class_ (HH.ClassName "didascalia")
        , HP.draggable true
        , HE.onClick \_ -> Remove
        , HE.onDragStart DragStart
        , HE.onDragLeave DragLeave
        , HE.onDragOver DragOver
        , HE.onDrop Drop
        ]
        [
          if st.editingAddress then
            HH.div
              [ HP.class_ (HH.ClassName "address editing")
              , HE.onClick SwallowDidascaliaClick
              ]
              [ HH.input
                  [ HP.value st.pericope.address
                  , HE.onValueInput SetAddress
                  , HE.onKeyDown \ke ->
                      if key ke == "Enter" then SubmitAddress else Noop
                  , HP.autofocus true
                  ]
              ]
          else
            HH.div
              [ HP.class_ (HH.ClassName "address")
              , HE.onClick HandleAddressClick
              ]
              [ HH.text st.pericope.address ]

        , if st.editingSource then
            let
              sourceList = case st.sources of
                Nothing ->
                  [ HH.div [ HP.class_ (HH.ClassName "source-loading") ]
                      [ HH.text "Loading sources..." ]
                  ]
                Just infos ->
                  if A.null infos then
                    [ HH.div [ HP.class_ (HH.ClassName "source-empty") ]
                        [ HH.text "Unable to load sources." ]
                    ]
                  else
                    let
                      languages = Set.toUnfoldable (Set.fromFoldable (infos <#> (unwrap >>> _.language))) :: Array String
                      renderOption infoRec =
                        let
                          info = unwrap infoRec
                          isActive = info.name == st.pericope.source
                          cls = "source-option" <> if isActive then " active" else ""
                        in
                        HH.li
                          [ HP.class_ (HH.ClassName cls)
                          , HE.onClick \_ -> SelectSource info.name
                          ]
                          [ HH.div [ HP.class_ (HH.ClassName "source-option-name") ] [ HH.text info.name ]
                          , HH.div [ HP.class_ (HH.ClassName "source-option-description") ] [ HH.text info.description_short ]
                          ]
                      renderGroup lang =
                        let
                          entries = infos # A.filter (\infoRec -> (unwrap infoRec).language == lang)
                          sorted = A.sortBy (comparing (unwrap >>> _.name)) entries
                        in
                        HH.div [ HP.class_ (HH.ClassName "source-language-group") ]
                          [ HH.h4 [ HP.class_ (HH.ClassName "source-language") ] [ HH.text lang ]
                          , HH.ul [ HP.class_ (HH.ClassName "source-options") ] (renderOption <$> sorted)
                          ]
                      sortedLanguages = A.sort languages
                    in
                    [ HH.div [ HP.class_ (HH.ClassName "source-list") ] (renderGroup <$> sortedLanguages)
                    ]
            in
            HH.div
              [ HP.class_ (HH.ClassName "source editing")
              , HE.onClick SwallowDidascaliaClick
              ]
              ([ HH.input
                    [ HP.value st.pericope.source
                    , HE.onValueInput SetSource
                    , HE.onKeyDown \ke ->
                        if key ke == "Enter" then SubmitSource else Noop
                    ]
                ] <> sourceList)
          else
            HH.div
              [ HP.class_ (HH.ClassName "source")
              , HE.onClick HandleSourceClick
              ]
              [ HH.text st.pericope.source ]
        , HH.div
            [ HP.class_ (HH.ClassName "selected-address") ]
            [ HH.text addressText ]
        ]

    , HH.div [ HP.class_ (HH.ClassName "textus") ]
        (st.pericope.verses <#> \(Verse v) ->
          let sel = Set.member v.verse_id st.pericope.selected in
          HH.div
            [ HP.class_ (HH.ClassName ("verse" <> if sel then " selected" else ""))
            , HP.attr (HH.AttrName "data-chapter") (show v.chapter)
            , HP.attr (HH.AttrName "data-verse") (show v.verse)
            , HE.onClick \_ -> ToggleSelect v.verse_id
            ]
            [ HH.text v.text ]
        )
    ]

handle :: forall m. MonadAff m => Action -> H.HalogenM State Action () Output m Unit
handle = case _ of
  Noop ->
    pure unit

  HandleAddressClick ev -> do
    H.liftEffect $ stopPropagation (toEvent ev)
    if ctrlKey ev then do
      st <- H.get
      H.raise (DidDuplicate { id: st.pericope.id })
    else
      H.modify_ _ { editingAddress = true }

  HandleSourceClick ev -> do
    H.liftEffect $ stopPropagation (toEvent ev)
    if ctrlKey ev then do
      st <- H.get
      H.raise (DidDuplicate { id: st.pericope.id })
    else do
      H.modify_ _ { editingSource = true }
      st <- H.get
      case st.sources of
        Just _ -> pure unit
        Nothing -> do
          res <- H.liftAff fetchSources
          case res of
            Left _ -> H.modify_ _ { sources = Just [] }
            Right srcs -> H.modify_ _ { sources = Just srcs }

  SwallowDidascaliaClick ev ->
    H.liftEffect $ stopPropagation (toEvent ev)

  SetAddress a ->
    H.modify_ \st -> st { pericope = st.pericope { address = a } }

  SetSource s ->
    H.modify_ \st -> st { pericope = st.pericope { source  = s } }

  SubmitAddress -> do
    st <- H.get
    H.modify_ _ { editingAddress = false }
    launchFetch st.pericope.address st.pericope.source

  SubmitSource -> do
    st <- H.get
    H.modify_ _ { editingSource = false }
    launchFetch st.pericope.address st.pericope.source

  SelectSource newSource -> do
    H.modify_ \st ->
      st
        { pericope = st.pericope { source = newSource }
        , editingSource = false
        }
    st <- H.get
    launchFetch st.pericope.address newSource

  ToggleSelect vid ->
    H.modify_ \st ->
      let sel0 = st.pericope.selected
          sel1 = if Set.member vid sel0 then Set.delete vid sel0 else Set.insert vid sel0
      in st { pericope = st.pericope { selected = sel1 } }

  Remove -> do
    st <- H.get
    H.raise (DidRemove st.pericope.id)

  DragStart ev -> do
    H.liftEffect $ stopPropagation (DragEv.toEvent ev)
    st <- H.get
    H.raise (DidStartDrag st.pericope.id)

  DragOver ev -> do
    H.liftEffect do
      preventDefault (DragEv.toEvent ev)
      stopPropagation (DragEv.toEvent ev)
    st <- H.get
    H.raise (DidDragOver st.pericope.id)

  DragLeave _ -> do
    st <- H.get
    H.raise (DidDragLeave st.pericope.id)

  Drop ev -> do
    H.liftEffect do
      preventDefault (DragEv.toEvent ev)
      stopPropagation (DragEv.toEvent ev)
    st <- H.get
    H.raise (DidReorder { from: st.pericope.id, to: st.pericope.id }) -- parent interprets drop target

  Receive p ->
    H.modify_ \st -> st { pericope = p }

launchFetch :: forall m. MonadAff m => Address -> Source -> H.HalogenM State Action () Output m Unit
launchFetch address source = do
  res <- H.liftAff $ fetchVerses address source
  case res of
    Left _  -> pure unit
    Right vs -> do
      H.modify_ \st -> st { pericope = st.pericope { verses = vs } }
      st' <- H.get
      H.raise (DidUpdate st'.pericope)
