module Main where

import Prelude

import Api (fetchVerses)
import Control.Monad (when)
import Data.Array as A
import Data.Either (Either(..))
import Data.Foldable (for_)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Set as Set
import Data.Void (Void)
import Data.Const (Const)
import Effect (Effect)
import Effect.Aff (Aff)
import Halogen as H
import Halogen.Aff as HA
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Halogen.HTML.Properties.ARIA as HPA
import Halogen.VDom.Driver (runUI)
import Type.Proxy (Proxy(..))

import Pericope as P
import Types (AppState, Pericope, PericopeId, Verse)
import UrlState (loadSeeds, pericopesToSeeds, storeSeeds)
import Web.HTML.HTMLElement (focus)
import Web.UIEvent.KeyboardEvent (KeyboardEvent, key)

main :: Effect Unit
main = HA.runHalogenAff do
  body <- HA.awaitBody
  runUI component unit body

type ChildSlots =
  ( pericope :: H.Slot P.Query P.Output PericopeId )

pericopeSlot :: Proxy "pericope"
pericopeSlot = Proxy

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
  | OpenHelp
  | CloseHelp
  | HandleHelpKey KeyboardEvent

initialState :: Unit -> AppState
initialState _ =
  { pericopes: []
  , dragging: Nothing
  , droppingOver: Nothing
  , nextId: 1
  , helpOpen: false
  }

helpModalRef :: H.RefLabel
helpModalRef = H.RefLabel "help-modal"

render :: AppState -> H.ComponentHTML Action ChildSlots Aff
render st =
  HH.div_
    ( [ HH.div_
          (renderPericope <$> st.pericopes)
      , renderHelpLink st.helpOpen
      ] <> renderHelpModal st.helpOpen
    )

renderPericope :: Pericope -> H.ComponentHTML Action ChildSlots Aff
renderPericope p =
  HH.slot pericopeSlot p.id P.component p (ChildMsg p.id)

renderHelpLink :: Boolean -> H.ComponentHTML Action ChildSlots Aff
renderHelpLink isOpen =
  let
    attrs =
      [ HP.class_ (HH.ClassName "help-footer")
      ]
  in
  HH.div attrs
    [ HH.a
        [ HP.href "#help"
        , HP.class_ (HH.ClassName "help-link")
        , HPA.role "button"
        , HP.attr (HH.AttrName "aria-expanded") (if isOpen then "true" else "false")
        , HE.onClick \_ -> OpenHelp
        ]
        [ HH.text "help" ]
    ]

renderHelpModal :: Boolean -> Array (H.ComponentHTML Action ChildSlots Aff)
renderHelpModal false = []
renderHelpModal true =
  [ HH.div
      [ HP.class_ (HH.ClassName "help-modal-backdrop")
      ]
      [ HH.div
          [ HP.class_ (HH.ClassName "help-modal")
          , HP.id "help-modal"
          , HP.ref helpModalRef
          , HP.tabIndex 0
          , HE.onKeyDown HandleHelpKey
          ]
          [ HH.h3_ [ HH.text "How to use deepbible" ]
          , HH.dl_
              [ HH.dt_ [ HH.text "Click address ⇨ type ⇨ Enter" ]
              , HH.dd_ [ HH.text "change pericope address" ]
              , HH.dt_ [ HH.text "Click source name ⇨ type ⇨ Enter" ]
              , HH.dd_ [ HH.text "change pericope source" ]
              , HH.dt_ [ HH.text "Click source name ⇨ select from list" ]
              , HH.dd_ [ HH.text "change pericope source" ]
              , HH.dt_ [ HH.text "Ctrl + Click left margin" ]
              , HH.dd_ [ HH.text "duplicate pericope" ]
              , HH.dt_ [ HH.text "Click ✕ " ]
              , HH.dd_ [ HH.text "delete pericope" ]
              , HH.dt_ [ HH.text "Drag with ☰" ]
              , HH.dd_ [ HH.text "reorder pericopes" ]
              , HH.dt_ [ HH.text "Click verse" ]
              , HH.dd_ [ HH.text "highlight verse" ]
              , HH.dt_ [ HH.text "With one verse highlighted ⇨ click address (right margin)" ]
              , HH.dd_ [ HH.text "add verse as new pericope" ]
              , HH.dt_ [ HH.text "With any verse highlighted ⇨ click selection address (left margin)" ]
              , HH.dd_ [ HH.text "add verse(s) as new pericope" ]
              ]
          , HH.button
              [ HP.class_ (HH.ClassName "help-close")
              , HE.onClick \_ -> CloseHelp
              ]
              [ HH.text "Close" ]
          ]
      ]
  ]

handle :: Action -> H.HalogenM AppState Action ChildSlots Void Aff Unit
handle action = case action of
  Initialize -> do
    urlSeeds <- H.liftEffect loadSeeds
    let defaultSeeds =
          [ { address: "J 3,16-17", source: "NVUL" }
          , { address: "J 3,16-17", source: "NA28" }
          , { address: "J 3,16-17", source: "PAU" }
          ]
        seeds = if A.null urlSeeds then defaultSeeds else urlSeeds
    for_ seeds \{ address, source } -> do
      res <- H.liftAff $ fetchVerses address source
      case res of
        Left _ -> pure unit
        Right verses -> insertPericope address source verses

  AddPericope addr src verses ->
    insertPericope addr src verses

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

  OpenHelp -> do
    H.modify_ \st -> st { helpOpen = true }
    mEl <- H.getHTMLElementRef helpModalRef
    for_ mEl (H.liftEffect <<< focus)

  CloseHelp ->
    H.modify_ \st -> st { helpOpen = false }

  HandleHelpKey ev ->
    when (key ev == "Escape") (handle CloseHelp)

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
