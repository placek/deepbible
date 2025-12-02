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
import Infrastructure.Api (fetchVerses)
import Pericope.Component as P
import Search.Component as Search
import Type.Proxy (Proxy(..))

import App.State (AppState)
import App.UrlState (loadSeeds, pericopesToSeeds, storeSeeds)
import Domain.Bible.Types (Verse)
import Domain.Pericope.Types (Pericope, PericopeId)

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
  | HandleSearch Search.Action
  | HandleDocumentClick

initialState :: Unit -> AppState
initialState _ =
  { pericopes: []
  , dragging: Nothing
  , droppingOver: Nothing
  , nextId: 1
  , searchInput: ""
  , searchResults: []
  , aiSearchResults: []
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
  HH.div
    [ HE.onClick \_ -> HandleDocumentClick ]
    [ Search.renderSearchSection HandleSearch st
    , HH.div_
        (renderPericope <$> st.pericopes)
    , renderFooter
    ]

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

  HandleSearch searchAction ->
    Search.handleAction insertPericope searchAction

  HandleDocumentClick -> do
    Search.handleAction insertPericope Search.CloseSearchResults
    st <- H.get
    for_ st.pericopes cancelEditing

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
