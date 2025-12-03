module App.Main where

import Prelude

import Data.Array as A
import Data.Const (Const)
import Data.Either (Either(..))
import Data.Foldable (for_)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Set as Set
import Effect (Effect)
import Effect.Aff (Aff)
import Halogen as H
import Halogen.Aff as HA
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Halogen.VDom.Driver (runUI)
import Infrastructure.Api (checkAiStatus, fetchVerses)
import Pericope.Component as P
import Search.Component as Search
import Type.Proxy (Proxy(..))

import App.State (AppState, Item(..))
import App.UrlState (ItemSeed, itemsToSeeds, loadSeeds, storeSeeds)
import Domain.Bible.Types (Verse)
import Domain.Note.Types (Note, NoteId)
import Domain.Pericope.Types (Pericope, PericopeId)
import Note.Component as N

main :: Effect Unit
main = HA.runHalogenAff do
  body <- HA.awaitBody
  runUI component unit body

type ChildSlots =
  ( pericope :: H.Slot P.Query P.Output PericopeId
  , note :: H.Slot N.Query N.Output NoteId
  )

pericopeSlot :: Proxy "pericope"
pericopeSlot = Proxy

noteSlot :: Proxy "note"
noteSlot = Proxy

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
data ChildMessage
  = PericopeMsg PericopeId P.Output
  | NoteMsg NoteId N.Output

data Action
  = Initialize
  | AddPericope String String (Array Verse)
  | AddNoteAt Int
  | ChildMsg ChildMessage
  | StartDrag Int
  | OverDrag Int
  | LeaveDrag Int
  | DropOn Int
  | HandleSearch Search.Action
  | HandleDocumentClick

initialState :: Unit -> AppState
initialState _ =
  { items: []
  , dragging: Nothing
  , droppingOver: Nothing
  , nextId: 1
  , searchInput: ""
  , searchResults: []
  , aiSearchResults: []
  , aiStatusUp: false
  , aiSearchEnabled: false
  , searchOpen: false
  , searchPerformed: false
  , searchLoading: false
  , aiSearchLoading: false
  , searchError: Nothing
  , aiSearchError: Nothing
  }

render :: AppState -> H.ComponentHTML Action ChildSlots Aff
render st =
  let
    items =
      A.concat
        ( [ [ renderAddNoteButton 0 ] ]
            <> A.mapWithIndex renderItemWithAddButton st.items
        )
  in
  HH.div
    [ HE.onClick \_ -> HandleDocumentClick ]
    [ Search.renderSearchSection HandleSearch st
    , HH.div_ items
    , renderFooter
    ]

renderItemWithAddButton
  :: Int
  -> Item
  -> Array (H.ComponentHTML Action ChildSlots Aff)
renderItemWithAddButton index item =
  [ renderItem item
  , renderAddNoteButton (index + 1)
  ]

renderItem :: Item -> H.ComponentHTML Action ChildSlots Aff
renderItem item = case item of
  PericopeItem p -> renderPericope p
  NoteItem note -> renderNote note

renderPericope :: Pericope -> H.ComponentHTML Action ChildSlots Aff
renderPericope p =
  HH.slot pericopeSlot p.id P.component p (\out -> ChildMsg (PericopeMsg p.id out))

renderNote :: Note -> H.ComponentHTML Action ChildSlots Aff
renderNote n =
  HH.slot noteSlot n.id N.component n (\out -> ChildMsg (NoteMsg n.id out))

renderAddNoteButton :: Int -> H.ComponentHTML Action ChildSlots Aff
renderAddNoteButton index =
  HH.button
    [ HP.class_ (HH.ClassName "note-add")
    , HE.onClick \_ -> AddNoteAt index
    ]
    [ HH.text "+" ]

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
    aiStatusUp <- H.liftAff checkAiStatus
    H.modify_ \st -> st { aiStatusUp = aiStatusUp }
    urlSeeds <- H.liftEffect loadSeeds
    let defaultSeeds =
          [ pericopeSeed "J 3,16-17" "NVUL"
          , pericopeSeed "J 3,16-17" "NA28"
          , pericopeSeed "J 3,16-17" "BT_03"
          , pericopeSeed "J 3,16-17" "TRO+"
          ]
        seeds = if A.null urlSeeds then defaultSeeds else urlSeeds
    for_ seeds loadSeed

  AddPericope addr src verses ->
    insertPericope addr src verses

  AddNoteAt index ->
    insertNoteAt index ""

  HandleSearch searchAction ->
    Search.handleAction insertPericope searchAction

  HandleDocumentClick -> do
    Search.handleAction insertPericope Search.CloseSearchResults
    st <- H.get
    for_ st.items \item -> case item of
      PericopeItem p -> cancelEditing p
      _ -> pure unit

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
        let items = reorder fromId targetId st.items
        H.put st { items = items, dragging = Nothing, droppingOver = Nothing }
        syncUrl

  ChildMsg msg -> case msg of
    PericopeMsg pid out -> case out of
      P.DidDuplicate { id: baseId } -> do
        st <- H.get
        case findPericope baseId st.items of
          Nothing -> pure unit
          Just p -> do
            let addr = p.address
                src  = p.source
            res <- H.liftAff $ fetchVerses addr src
            case res of
              Left _ -> pure unit
              Right vs -> insertPericope addr src vs

      P.DidRemove rid -> do
        H.modify_ \st -> st { items = A.filter (\item -> itemId item /= rid) st.items }
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
          { items = st.items <#> updatePericope updated }
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

    NoteMsg nid out -> case out of
      N.DidDuplicate { id: baseId } -> do
        st <- H.get
        case findNote baseId st.items of
          Nothing -> pure unit
          Just { index, note } -> insertNoteAt (index + 1) note.content

      N.DidRemove rid -> do
        H.modify_ \st -> st { items = A.filter (\item -> itemId item /= rid) st.items }
        syncUrl

      N.DidStartDrag _ ->
        handle (StartDrag nid)

      N.DidDragOver _ ->
        handle (OverDrag nid)

      N.DidDragLeave _ ->
        handle (LeaveDrag nid)

      N.DidReorder _ ->
        handle (DropOn nid)

      N.DidUpdate updated -> do
        H.modify_ \st -> st
          { items = st.items <#> updateNote updated }
        syncUrl
  where
  cancelEditing
    :: Pericope
    -> H.HalogenM AppState Action ChildSlots Void Aff Unit
  cancelEditing p =
    void $ H.query pericopeSlot p.id (P.CancelEditing unit)

  pericopeSeed :: String -> String -> ItemSeed
  pericopeSeed address source =
    { kind: "pericope"
    , address
    , source
    , content: ""
    }

  loadSeed :: ItemSeed -> H.HalogenM AppState Action ChildSlots Void Aff Unit
  loadSeed seed = case seed.kind of
    "note" -> insertNoteAtEnd seed.content
    _ ->
      if seed.address /= "" && seed.source /= "" then do
        res <- H.liftAff $ fetchVerses seed.address seed.source
        case res of
          Left _ -> pure unit
          Right verses -> insertPericope seed.address seed.source verses
      else
        pure unit

-- Helpers
itemId :: Item -> Int
itemId = case _ of
  PericopeItem p -> p.id
  NoteItem n -> n.id

updatePericope :: Pericope -> Item -> Item
updatePericope updated = case _ of
  PericopeItem p | p.id == updated.id -> PericopeItem updated
  other -> other

updateNote :: Note -> Item -> Item
updateNote updated = case _ of
  NoteItem n | n.id == updated.id -> NoteItem updated
  other -> other

reorder :: Int -> Int -> Array Item -> Array Item
reorder fromId toId arr =
  let
    findIndexById id = A.findIndex (\item -> itemId item == id) arr
    fromIx = findIndexById fromId
    toIx   = findIndexById toId
  in case fromIx, toIx of
       Just i, Just j ->
         case A.index arr i, A.deleteAt i arr of
           Just item, Just arr' ->
             fromMaybe arr' (A.insertAt j item arr')
           _, _ -> arr
       _, _ -> arr

insertNoteAtEnd
  :: String
  -> H.HalogenM AppState Action ChildSlots Void Aff Unit
insertNoteAtEnd content = do
  st <- H.get
  insertNoteAt (A.length st.items) content

insertNoteAt
  :: Int
  -> String
  -> H.HalogenM AppState Action ChildSlots Void Aff Unit
insertNoteAt index content = do
  st <- H.get
  let nid = st.nextId
      note = { id: nid, content }
      clampedIndex = max 0 (min index (A.length st.items))
      items = fromMaybe (A.snoc st.items (NoteItem note)) (A.insertAt clampedIndex (NoteItem note) st.items)
  H.put st { items = items, nextId = st.nextId + 1 }
  syncUrl

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
    { items = A.snoc st.items (PericopeItem pericope)
    , nextId = st.nextId + 1
    }
  syncUrl

findPericope :: PericopeId -> Array Item -> Maybe Pericope
findPericope pid items = A.findMap (case _ of
  PericopeItem p | p.id == pid -> Just p
  _ -> Nothing) items

findNote :: NoteId -> Array Item -> Maybe { index :: Int, note :: Note }
findNote nid items = do
  index <- A.findIndex (\item -> itemId item == nid) items
  case A.index items index of
    Just (NoteItem note) -> Just { index, note }
    _ -> Nothing

syncUrl :: H.HalogenM AppState Action ChildSlots Void Aff Unit
syncUrl = do
  st <- H.get
  H.liftEffect $ storeSeeds (itemsToSeeds st.items)
