module Main where

import Prelude

import Api (fetchVerses, searchVerses)
import Data.Array as A
import Data.Either (Either(..))
import Data.Foldable (for_)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Newtype (unwrap)
import Data.Set as Set
import Data.Const (Const)
import Data.String.CodeUnits (fromCharArray, toCharArray)
import Data.String.Common (trim)
import Effect (Effect)
import Effect.Aff (Aff)
import Halogen as H
import Halogen.Aff as HA
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Halogen.VDom.Driver (runUI)
import Type.Proxy (Proxy(..))

import Pericope as P
import Types (AppState, Pericope, PericopeId, Verse, VerseSearchResult)
import UrlState (loadSeeds, pericopesToSeeds, storeSeeds)
import Web.Event.Event (stopPropagation)
import Web.UIEvent.KeyboardEvent (KeyboardEvent, key)
import Web.UIEvent.MouseEvent (MouseEvent, toEvent)

main :: Effect Unit
main = HA.runHalogenAff do
  body <- HA.awaitBody
  runUI component unit body

type ChildSlots =
  ( pericope :: H.Slot P.Query P.Output PericopeId )

pericopeSlot :: Proxy "pericope"
pericopeSlot = Proxy

type RootQuery :: Type -> Type
type RootQuery = Const Void

component :: H.Component RootQuery Unit Void Aff
component =
  H.mkComponent
    { initialState
    , render
    , eval: H.mkEval $ H.defaultEval
        { initialize = Just Initialize
        , handleAction = handle
        }
    }

-- Actions
data Action
  = Initialize
  | AddPericope String String (Array Verse)
  | ChildMsg PericopeId P.Output
  | StartDrag PericopeId
  | OverDrag PericopeId
  | LeaveDrag PericopeId
  | DropOn PericopeId
  | UpdateSearchInput String
  | SubmitSearch
  | ReceiveSearchResults (Either String (Array VerseSearchResult))
  | SelectSearchResult VerseSearchResult
  | FocusSearchInput
  | CloseSearchResults
  | HandleSearchKey KeyboardEvent
  | HandleDocumentClick
  | SearchInputClick MouseEvent
  | SearchResultsClick MouseEvent

initialState :: Unit -> AppState
initialState _ =
  { pericopes: []
  , dragging: Nothing
  , droppingOver: Nothing
  , nextId: 1
  , searchInput: ""
  , searchResults: []
  , searchOpen: false
  , searchPerformed: false
  , searchLoading: false
  , searchError: Nothing
  }

render :: AppState -> H.ComponentHTML Action ChildSlots Aff
render st =
  HH.div
    [ HE.onClick \_ -> HandleDocumentClick ]
    [ renderSearchSection st
    , HH.div_
        (renderPericope <$> st.pericopes)
    , renderFooter
    ]

renderSearchSection :: AppState -> H.ComponentHTML Action ChildSlots Aff
renderSearchSection st =
  HH.div
    [ HP.class_ (HH.ClassName "search-section") ]
    ( [ HH.div
          [ HP.class_ (HH.ClassName "search-input-group") ]
              [ HH.input
                  [ HP.attr (HH.AttrName "type") "text"
                  , HP.placeholder "Search verses"
                  , HP.value st.searchInput
                  , HE.onValueInput UpdateSearchInput
                  , HE.onFocus \_ -> FocusSearchInput
                  , HE.onClick SearchInputClick
                  , HE.onKeyDown HandleSearchKey
                  ]
              ]
          ]
        <> renderSearchFeedback st
        <> renderSearchResults st
    )

renderSearchFeedback :: AppState -> Array (H.ComponentHTML Action ChildSlots Aff)
renderSearchFeedback st =
  let
    baseAttrs = [ HP.class_ (HH.ClassName "search-status") ]
  in case st.searchLoading, st.searchError of
       true, _ ->
         [ HH.div baseAttrs [ HH.text "Searching…" ] ]
       false, Just err ->
         [ HH.div baseAttrs [ HH.text err ] ]
       false, Nothing ->
         if st.searchPerformed && A.null st.searchResults then
           [ HH.div baseAttrs [ HH.text "No results" ] ]
         else
           []

renderSearchResults :: AppState -> Array (H.ComponentHTML Action ChildSlots Aff)
renderSearchResults st =
  if not st.searchOpen || A.null st.searchResults then
    []
  else
    [ HH.ul
        [ HP.class_ (HH.ClassName "search-results list list-reset")
        , HE.onClick SearchResultsClick
        ]
        (st.searchResults <#> renderSearchResult)
    ]

renderSearchResult :: VerseSearchResult -> H.ComponentHTML Action ChildSlots Aff
renderSearchResult result =
  let
    details = unwrap result
  in
  HH.li
    [ HP.class_ (HH.ClassName "search-result")
    , HE.onClick \_ -> SelectSearchResult result
    ]
    [ HH.div
        [ HP.class_ (HH.ClassName "search-result-address") ]
        [ HH.text ("~" <> details.address) ]
    , HH.div
        [ HP.class_ (HH.ClassName "search-result-source") ]
        [ HH.text ("@" <> details.source) ]
    , HH.div
        [ HP.class_ (HH.ClassName "search-result-text") ]
        [ HH.text (stripTags details.text) ]
    ]

stripTags :: String -> String
stripTags = fromCharArray <<< go false <<< toCharArray
  where
  go :: Boolean -> Array Char -> Array Char
  go insideTag chars =
    case A.uncons chars of
      Nothing -> []
      Just { head: c, tail: cs }
        | c == '<' -> go true cs
        | c == '>' -> go false cs
        | insideTag -> go insideTag cs
        | otherwise -> A.cons c (go insideTag cs)

renderPericope :: Pericope -> H.ComponentHTML Action ChildSlots Aff
renderPericope p =
  HH.slot pericopeSlot p.id P.component p (ChildMsg p.id)

renderFooter :: H.ComponentHTML Action ChildSlots Aff
renderFooter =
  HH.div
    [ HP.class_ (HH.ClassName "app-footer") ]
    [ HH.a
        [ HP.href "https://github.com/placek/deepbible"
        , HP.attr (HH.AttrName "target") "_blank"
        , HP.attr (HH.AttrName "rel") "noreferrer"
        ]
        [ HH.text "github" ]
    ]

handle :: Action -> H.HalogenM AppState Action ChildSlots Void Aff Unit
handle action = case action of
  Initialize -> do
    urlSeeds <- H.liftEffect loadSeeds
    let defaultSeeds =
          [ { address: "J 3,16-17", source: "NVUL" }
          , { address: "J 3,16-17", source: "NA28" }
          , { address: "J 3,16-17", source: "BT_03" }
          , { address: "J 3,16-17", source: "TRO+" }
          ]
        seeds = if A.null urlSeeds then defaultSeeds else urlSeeds
    for_ seeds \{ address, source } -> do
      res <- H.liftAff $ fetchVerses address source
      case res of
        Left _ -> pure unit
        Right verses -> insertPericope address source verses

  AddPericope addr src verses ->
    insertPericope addr src verses

  UpdateSearchInput value ->
    H.modify_ \st -> st { searchInput = value }

  SubmitSearch -> do
    st <- H.get
    let query = trim st.searchInput
    if query == "" then
      pure unit
    else do
      H.modify_ \state -> state
        { searchInput = query
        , searchLoading = true
        , searchError = Nothing
        , searchOpen = true
        , searchPerformed = true
        , searchResults = []
        }
      res <- H.liftAff $ searchVerses query
      handle (ReceiveSearchResults res)

  ReceiveSearchResults res -> case res of
    Left err ->
      H.modify_ \st -> st
        { searchLoading = false
        , searchError = Just err
        , searchResults = []
        }
    Right results ->
      H.modify_ \st -> st
        { searchLoading = false
        , searchError = Nothing
        , searchResults = results
        , searchOpen = true
        }

  SelectSearchResult result -> do
    let details = unwrap result
    H.modify_ \st -> st { searchOpen = false }
    res <- H.liftAff $ fetchVerses details.address details.source
    case res of
      Left _ -> pure unit
      Right verses -> insertPericope details.address details.source verses

  FocusSearchInput ->
    H.modify_ \st ->
      if st.searchPerformed || st.searchLoading || (case st.searchError of
            Just _ -> true
            Nothing -> false
         )
      then st { searchOpen = true }
      else st

  CloseSearchResults ->
    H.modify_ \st -> st { searchOpen = false }

  HandleSearchKey ev -> case key ev of
    "Enter" -> handle SubmitSearch
    "Escape" -> handle CloseSearchResults
    _ -> pure unit

  HandleDocumentClick -> do
    H.modify_ \st -> st { searchOpen = false }
    st <- H.get
    for_ st.pericopes cancelEditing

  SearchInputClick ev -> do
    H.liftEffect $ stopPropagation (toEvent ev)
    handle FocusSearchInput

  SearchResultsClick ev ->
    H.liftEffect $ stopPropagation (toEvent ev)

  StartDrag pid ->
    H.modify_ \st -> st { dragging = Just pid }

  OverDrag pid  ->
    H.modify_ \st -> st { droppingOver = Just pid }

  LeaveDrag _   ->
    H.modify_ \st -> st { droppingOver = Nothing }

  DropOn targetId -> do
    st <- H.get
    case st.dragging of
      Nothing -> pure unit
      Just fromId -> do
        let ps = reorder fromId targetId st.pericopes
        H.put st { pericopes = ps, dragging = Nothing, droppingOver = Nothing }
        syncUrl

  ChildMsg pid out -> case out of
    P.DidDuplicate { id: baseId } -> do
      st <- H.get
      case A.find (\q -> q.id == baseId) st.pericopes of
        Nothing -> pure unit
        Just p -> do
          let addr = p.address
              src  = p.source
          res <- H.liftAff $ fetchVerses addr src
          case res of
            Left _ -> pure unit
            Right vs -> insertPericope addr src vs

    P.DidRemove rid -> do
      H.modify_ \st ->
        if A.length st.pericopes > 1 then
          st { pericopes = A.filter (\q -> q.id /= rid) st.pericopes }
        else
          st
      syncUrl

    P.DidStartDrag _ ->
      handle (StartDrag pid)

    P.DidDragOver _ ->
      handle (OverDrag pid)

    P.DidDragLeave _ ->
      handle (LeaveDrag pid)

    P.DidReorder _ ->
      handle (DropOn pid)

    P.DidUpdate updated -> do
      H.modify_ \st -> st
        { pericopes = st.pericopes <#> \q -> if q.id == updated.id then updated else q }
      syncUrl

    P.DidLoadCrossReference { source, address } -> do
      res <- H.liftAff $ fetchVerses address source
      case res of
        Left _ -> pure unit
        Right verses -> insertPericope address source verses

    P.DidCreatePericopeFromSelection { source, address } -> do
      res <- H.liftAff $ fetchVerses address source
      case res of
        Left _ -> pure unit
        Right verses -> insertPericope address source verses

    P.DidLoadStory { source, address } -> do
      res <- H.liftAff $ fetchVerses address source
      case res of
        Left _ -> pure unit
        Right verses -> insertPericope address source verses

  where
  cancelEditing
    :: Pericope
    -> H.HalogenM AppState Action ChildSlots Void Aff Unit
  cancelEditing p =
    void $ H.query pericopeSlot p.id (P.CancelEditing unit)

-- Reorder helper (total, no partial indexing)
reorder :: PericopeId -> PericopeId -> Array Pericope -> Array Pericope
reorder fromId toId arr =
  let
    fromIx = A.findIndex (\p -> p.id == fromId) arr
    toIx   = A.findIndex (\p -> p.id == toId) arr
  in case fromIx, toIx of
       Just i, Just j ->
         case A.index arr i, A.deleteAt i arr of
           Just item, Just arr' ->
             fromMaybe arr' (A.insertAt j item arr')
           _, _ -> arr
       _, _ -> arr

insertPericope
  :: String
  -> String
  -> Array Verse
  -> H.HalogenM AppState Action ChildSlots Void Aff Unit
insertPericope address source verses = do
  st <- H.get
  let pid = st.nextId
      pericope =
        { id: pid
        , address
        , source
        , verses
        , selected: Set.empty
        }
  H.put st
    { pericopes = A.snoc st.pericopes pericope
    , nextId = st.nextId + 1
    }
  syncUrl

syncUrl :: H.HalogenM AppState Action ChildSlots Void Aff Unit
syncUrl = do
  st <- H.get
  H.liftEffect $ storeSeeds (pericopesToSeeds st.pericopes)
