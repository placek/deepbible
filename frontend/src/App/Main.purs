module App.Main where

import Prelude

import Data.Array as A
import Data.Const (Const)
import Data.Either (Either(..))
import Data.Foldable (for_)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Set as Set
import Data.String.CodeUnits (fromCharArray, toCharArray)
import Data.String.Common (trim)
import Effect (Effect)
import Effect.Aff (Aff, launchAff_)
import Halogen as H
import Halogen.Aff as HA
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Halogen.VDom.Driver (runUI)
import Infrastructure.Api (fetchSheet, fetchVerses, upsertSheet)
import Infrastructure.LocalStorage (SavedSheetEntry, saveSheetToLocal, loadSheetList, deleteSheetFromLocal, navigateToSheet)
import Pericope.Component as P
import Search.Component as Search
import Type.Proxy (Proxy(..))

import App.Markdown (downloadMarkdownFile, renderSheetMarkdown, slugify)
import App.State (AppState, Item(..))
import App.UrlState (ItemSeed(..), decodeSheet, encodeSheet, getOrCreateSheetId, getSearchQueryParam, itemsToSeeds)
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
  | AddPericopeAt Int
  | DownloadMarkdown
  | ChildMsg ChildMessage
  | StartDrag Int
  | OverDrag Int
  | LeaveDrag Int
  | DropOn Int
  | HandleSearch Search.Action
  | HandleDocumentClick
  | UpdateTitle String
  | ToggleSheetList
  | RecallSheet String
  | DeleteSavedSheet String

initialState :: Unit -> AppState
initialState _ =
  { items: []
  , dragging: Nothing
  , droppingOver: Nothing
  , sheetId: ""
  , title: ""
  , hydrating: false
  , nextId: 1
  , searchInput: ""
  , searchResults: []
  , searchOpen: false
  , searchPerformed: false
  , searchLoading: false
  , searchError: Nothing
  , savedSheets: []
  , sheetListOpen: false
  }

defaultSeeds :: Array ItemSeed
defaultSeeds =
  [ pericopeSeed "J 3,16-17" "NVUL"
  , pericopeSeed "J 3,16-17" "NA28"
  , pericopeSeed "J 3,16-17" "BT_03"
  , pericopeSeed "J 3,16-17" "TRO+"
  ]

pericopeSeed :: String -> String -> ItemSeed
pericopeSeed address source =
  ItemSeed
    { kind: "pericope"
    , address
    , source
    , content: ""
    }

render :: AppState -> H.ComponentHTML Action ChildSlots Aff
render st =
  let
    items =
      A.concat
        ( [ [ renderAddButtons 0 ] ]
            <> A.mapWithIndex renderItemWithAddButton st.items
        )
  in
  HH.div
    [ HE.onClick \_ -> HandleDocumentClick ]
    [ renderHeader st.title
    , Search.renderSearchSection HandleSearch st
    , HH.div_ items
    , renderFooter st
    ]

renderHeader :: String -> H.ComponentHTML Action ChildSlots Aff
renderHeader title =
  HH.div
    [ HP.class_ (HH.ClassName "app-header") ]
    [ HH.input
        [ HP.class_ (HH.ClassName "app-title")
        , HP.value title
        , HP.placeholder "untitled sheet"
        , HE.onValueInput UpdateTitle
        ]
    ]

renderItemWithAddButton
  :: Int
  -> Item
  -> Array (H.ComponentHTML Action ChildSlots Aff)
renderItemWithAddButton index item =
  [ renderItem item
  , renderAddButtons (index + 1)
  ]

renderAddButtons :: Int -> H.ComponentHTML Action ChildSlots Aff
renderAddButtons index =
  HH.div
    [ HP.class_ (HH.ClassName "add-buttons") ]
    [ renderAddNoteButton index
    , renderAddPericopeButton index
    ]

renderAddPericopeButton :: Int -> H.ComponentHTML Action ChildSlots Aff
renderAddPericopeButton index =
  HH.button
    [ HP.class_ (HH.ClassName "pericope-add")
    , HE.onClick \_ -> AddPericopeAt index
    ]
    [ HH.text "+" ]

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

sheetMarkdownFilename :: String -> String -> String
sheetMarkdownFilename title sheetId =
  let slug = slugify title
  in case slug == "", sheetId == "" of
    true, true -> "deepbible-sheet.md"
    true, false -> "deepbible-sheet-" <> sheetId <> ".md"
    false, true -> slug <> ".md"
    false, false -> slug <> "-" <> sheetId <> ".md"

renderFooter :: AppState -> H.ComponentHTML Action ChildSlots Aff
renderFooter st =
  HH.div
    [ HP.class_ (HH.ClassName "app-footer-container") ]
    ( ( if st.sheetListOpen then [ renderSheetList st.sheetId st.savedSheets ] else [] )
      <>
      [ HH.div
          [ HP.class_ (HH.ClassName "app-footer") ]
          [ HH.button
              [ HP.class_ (HH.ClassName "app-footer-action")
              , HP.title "saved sheets"
              , HE.onClick \_ -> ToggleSheetList
              ]
              [ HH.text ("sheets (" <> show (A.length st.savedSheets) <> ")") ]
          , HH.button
              [ HP.class_ (HH.ClassName "app-footer-action")
              , HP.title "download sheet as markdown"
              , HE.onClick \_ -> DownloadMarkdown
              ]
              [ HH.text (sheetMarkdownFilename st.title st.sheetId) ]
          , HH.a
              [ HP.href "https://github.com/placek/deepbible"
              , HP.attr (HH.AttrName "target") "_blank"
              , HP.attr (HH.AttrName "rel") "noreferrer"
              ]
              [ HH.text "github" ]
          ]
      ]
    )

renderSheetList
  :: String
  -> Array SavedSheetEntry
  -> H.ComponentHTML Action ChildSlots Aff
renderSheetList currentSheetId sheets =
  HH.div
    [ HP.class_ (HH.ClassName "sheet-list") ]
    ( if A.null sheets then
        [ HH.div
            [ HP.class_ (HH.ClassName "sheet-list-empty") ]
            [ HH.text "no saved sheets" ]
        ]
      else
        sheets <#> renderSheetEntry currentSheetId
    )

renderSheetEntry
  :: String
  -> SavedSheetEntry
  -> H.ComponentHTML Action ChildSlots Aff
renderSheetEntry currentSheetId entry =
  let
    isCurrent = entry.sheetId == currentSheetId
    label = if entry.title == "" then "untitled sheet" else entry.title
    classes =
      "sheet-list-entry"
        <> (if isCurrent then " sheet-list-entry--current" else "")
  in
  HH.div
    [ HP.class_ (HH.ClassName classes) ]
    [ HH.button
        [ HP.class_ (HH.ClassName "sheet-list-title")
        , HP.title entry.sheetId
        , HE.onClick \_ -> RecallSheet entry.sheetId
        ]
        [ HH.text label ]
    , HH.span
        [ HP.class_ (HH.ClassName "sheet-list-date") ]
        [ HH.text (formatSavedAt entry.savedAt) ]
    , if isCurrent then HH.text ""
      else
        HH.button
          [ HP.class_ (HH.ClassName "sheet-list-delete")
          , HP.title "remove from list"
          , HE.onClick \_ -> DeleteSavedSheet entry.sheetId
          ]
          [ HH.text "\x00d7" ]
    ]

formatSavedAt :: String -> String
formatSavedAt s =
  let
    datePart = A.take 10 (A.fromFoldable (toCharArray s))
  in
    if A.length datePart == 10 then fromCharArray datePart else s

handle :: Action -> H.HalogenM AppState Action ChildSlots Void Aff Unit
handle action = case action of
  Initialize -> do
    sheetId <- H.liftEffect getOrCreateSheetId
    savedSheets <- H.liftEffect loadSheetList
    H.modify_ \st -> st { sheetId = sheetId, hydrating = true, savedSheets = savedSheets }
    res <- H.liftAff $ fetchSheet sheetId
    let loaded = case res of
          Left _ -> { title: "", items: [] }
          Right maybeData -> case maybeData of
            Nothing -> { title: "", items: [] }
            Just dataJson -> decodeSheet dataJson
        seeds = if A.null loaded.items then defaultSeeds else loaded.items
    H.modify_ \st -> st { title = loaded.title }
    for_ seeds loadSeed
    H.modify_ \st -> st { hydrating = false }
    rawQuery <- H.liftEffect getSearchQueryParam
    let query = trim rawQuery
    if query == "" then
      pure unit
    else do
      Search.handleAction insertPericope (Search.UpdateSearchInput rawQuery)
      Search.handleAction insertPericope Search.SubmitSearch

  AddPericope addr src verses ->
    insertPericope addr src verses

  AddNoteAt index ->
    insertNoteAt index ""

  AddPericopeAt index -> do
    st <- H.get
    let source = sourceAbove index st.items
    fetchAndInsertPericopeAt index "2Tm 3,16" source

  DownloadMarkdown -> do
    st <- H.get
    let
      filename = sheetMarkdownFilename st.title st.sheetId
      markdown = renderSheetMarkdown st.title st.items
    H.liftEffect $ downloadMarkdownFile filename markdown

  HandleSearch searchAction ->
    Search.handleAction insertPericope searchAction

  ToggleSheetList ->
    H.modify_ \st -> st { sheetListOpen = not st.sheetListOpen }

  RecallSheet sheetId ->
    H.liftEffect $ navigateToSheet sheetId

  DeleteSavedSheet sheetId -> do
    H.liftEffect $ deleteSheetFromLocal sheetId
    savedSheets <- H.liftEffect loadSheetList
    H.modify_ \st -> st { savedSheets = savedSheets }

  HandleDocumentClick ->
    handleDocumentClick

  UpdateTitle title -> do
    H.modify_ \st -> st { title = title }
    syncSheet

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
        syncSheet

  ChildMsg msg -> case msg of
    PericopeMsg pid out ->
      handlePericopeOutput pid out
    NoteMsg nid out ->
      handleNoteOutput nid out

handleDocumentClick :: H.HalogenM AppState Action ChildSlots Void Aff Unit
handleDocumentClick = do
  Search.handleAction insertPericope Search.CloseSearchResults
  st <- H.get
  for_ st.items \item -> case item of
    PericopeItem p -> cancelEditing p
    _ -> pure unit

handlePericopeOutput
  :: PericopeId
  -> P.Output
  -> H.HalogenM AppState Action ChildSlots Void Aff Unit
handlePericopeOutput pid = case _ of
  P.DidDuplicate { id: baseId } -> do
    st <- H.get
    case findPericope baseId st.items of
      Nothing -> pure unit
      Just p -> fetchAndInsertPericope p.address p.source

  P.DidRemove rid ->
    removeItemById rid

  P.DidStartDrag _ ->
    handle (StartDrag pid)

  P.DidDragOver _ ->
    handle (OverDrag pid)

  P.DidDragLeave _ ->
    handle (LeaveDrag pid)

  P.DidReorder _ ->
    handle (DropOn pid)

  P.DidUpdate updated ->
    updateItemsAndSync (\items -> items <#> updatePericope updated)

  P.DidLoadCrossReference { source, address } ->
    fetchAndInsertPericope address source

  P.DidCreatePericopeFromSelection { source, address } ->
    fetchAndInsertPericope address source

  P.DidLoadStory { source, address } ->
    fetchAndInsertPericope address source

handleNoteOutput
  :: NoteId
  -> N.Output
  -> H.HalogenM AppState Action ChildSlots Void Aff Unit
handleNoteOutput nid = case _ of
  N.DidDuplicate { id: baseId } -> do
    st <- H.get
    case findNote baseId st.items of
      Nothing -> pure unit
      Just { index, note } -> insertNoteAt (index + 1) note.content

  N.DidRemove rid ->
    removeItemById rid

  N.DidStartDrag _ ->
    handle (StartDrag nid)

  N.DidDragOver _ ->
    handle (OverDrag nid)

  N.DidDragLeave _ ->
    handle (LeaveDrag nid)

  N.DidReorder _ ->
    handle (DropOn nid)

  N.DidUpdate updated ->
    updateItemsAndSync (\items -> items <#> updateNote updated)

cancelEditing
  :: Pericope
  -> H.HalogenM AppState Action ChildSlots Void Aff Unit
cancelEditing p =
  void $ H.query pericopeSlot p.id (P.CancelEditing unit)

loadSeed :: ItemSeed -> H.HalogenM AppState Action ChildSlots Void Aff Unit
loadSeed (ItemSeed seed) = case seed.kind of
  "note" ->
    insertNoteAtEnd seed.content
  _ ->
    if seed.address /= "" && seed.source /= "" then
      fetchAndInsertPericope seed.address seed.source
    else
      pure unit

fetchAndInsertPericope
  :: String
  -> String
  -> H.HalogenM AppState Action ChildSlots Void Aff Unit
fetchAndInsertPericope address source = do
  res <- H.liftAff $ fetchVerses address source
  case res of
    Left _ -> pure unit
    Right verses -> insertPericope address source verses

fetchAndInsertPericopeAt
  :: Int
  -> String
  -> String
  -> H.HalogenM AppState Action ChildSlots Void Aff Unit
fetchAndInsertPericopeAt index address source = do
  res <- H.liftAff $ fetchVerses address source
  case res of
    Left _ -> pure unit
    Right verses -> insertPericopeAt index address source verses

sourceAbove :: Int -> Array Item -> String
sourceAbove index items =
  let
    before = A.take index items
    lastP = A.findMap (case _ of
      PericopeItem p -> Just p.source
      _ -> Nothing) (A.reverse before)
  in fromMaybe "NVUL" lastP

updateItemsAndSync
  :: (Array Item -> Array Item)
  -> H.HalogenM AppState Action ChildSlots Void Aff Unit
updateItemsAndSync updateItems = do
  H.modify_ \st -> st { items = updateItems st.items }
  syncSheet

removeItemById :: Int -> H.HalogenM AppState Action ChildSlots Void Aff Unit
removeItemById rid =
  updateItemsAndSync (A.filter (\item -> itemId item /= rid))

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
  syncSheet

insertPericope
  :: String
  -> String
  -> Array Verse
  -> H.HalogenM AppState Action ChildSlots Void Aff Unit
insertPericope address source verses = do
  st <- H.get
  insertPericopeAt (A.length st.items) address source verses

insertPericopeAt
  :: Int
  -> String
  -> String
  -> Array Verse
  -> H.HalogenM AppState Action ChildSlots Void Aff Unit
insertPericopeAt index address source verses = do
  st <- H.get
  let pid = st.nextId
      pericope =
        { id: pid
        , address
        , source
        , verses
        , selected: Set.empty
        }
      clampedIndex = max 0 (min index (A.length st.items))
      items = fromMaybe (A.snoc st.items (PericopeItem pericope))
        (A.insertAt clampedIndex (PericopeItem pericope) st.items)
  H.put st { items = items, nextId = st.nextId + 1 }
  syncSheet

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

syncSheet :: H.HalogenM AppState Action ChildSlots Void Aff Unit
syncSheet = do
  st <- H.get
  if st.hydrating || st.sheetId == "" then
    pure unit
  else do
    let payload = encodeSheet st.title (itemsToSeeds st.items)
    H.liftEffect do
      saveSheetToLocal st.sheetId payload
      launchAff_ do
        void $ upsertSheet st.sheetId payload
    savedSheets <- H.liftEffect loadSheetList
    H.modify_ \s -> s { savedSheets = savedSheets }
