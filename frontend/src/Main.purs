module Main where

import Prelude

import Api (fetchVerses)
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
import Halogen.VDom.Driver (runUI)
import Type.Proxy (Proxy(..))

import Pericope as P
import Types (AppState, Pericope, PericopeId, Verse)

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

initialState :: Unit -> AppState
initialState _ =
  { pericopes: []
  , dragging: Nothing
  , droppingOver: Nothing
  , nextId: 1
  }

render :: AppState -> H.ComponentHTML Action ChildSlots Aff
render st =
  HH.div_
    (renderPericope <$> st.pericopes)

renderPericope :: Pericope -> H.ComponentHTML Action ChildSlots Aff
renderPericope p =
  HH.slot pericopeSlot p.id P.component p (ChildMsg p.id)

handle :: Action -> H.HalogenM AppState Action ChildSlots Void Aff Unit
handle action = case action of
  Initialize -> do
    let seeds =
          [ { address: "J 3,16-17", source: "NVUL" }
          , { address: "J 3,16-17", source: "PAU" }
          ]
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

    P.DidRemove rid ->
      H.modify_ \st ->
        if A.length st.pericopes > 1 then
          st { pericopes = A.filter (\q -> q.id /= rid) st.pericopes }
        else
          st

    P.DidStartDrag _ ->
      handle (StartDrag pid)

    P.DidDragOver _ ->
      handle (OverDrag pid)

    P.DidDragLeave _ ->
      handle (LeaveDrag pid)

    P.DidReorder _ ->
      handle (DropOn pid)

    P.DidUpdate updated ->
      H.modify_ \st -> st
        { pericopes = st.pericopes <#> \q -> if q.id == updated.id then updated else q }

    P.DidLoadCrossReference { source, address } -> do
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
