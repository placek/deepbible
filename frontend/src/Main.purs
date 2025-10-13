module Main where

import Prelude

import Api (fetchVerses)
import Data.Array as A
import Data.Either (Either(..))
import Data.Foldable (for_)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Set as Set
import Effect (Effect)
import Effect.Aff (launchAff_)
import Halogen as H
import Halogen.Aff as HA
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Halogen.VDom.Driver (runUI)
import Pericope as P
import Types (AppState, Pericope, PericopeId(..), Verse(..))

main :: Effect Unit
main = HA.runHalogenAff do
  body <- HA.awaitBody
  runUI component unit body

component :: H.Component HH.HTML Unit Void Unit
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

render :: AppState -> H.ComponentHTML () Action
render st =
  HH.div_
    (st.pericopes <#> renderPericope st)

renderPericope :: forall a . AppState -> Pericope -> HH.HTML a Action
renderPericope _st p =
  HH.slot p.id unit P.component p (ChildMsg p.id)

handle :: Action -> H.HalogenM AppState Action () Void Unit
handle = case _ of
  Initialize -> do
    let add addr src = launchAff_ do
          res <- fetchVerses { address: addr, source: src }
          H.liftEffect case res of
            Left _ -> pure unit
            Right vs -> H.raise (AddPericope addr src vs)
    -- seed like your example
    add "J 3,16-17" "NVUL"
    add "J 3,16-17" "PAU"

  AddPericope addr src verses -> do
    st <- H.get
    let pid = st.nextId
        pericope =
          { id: pid
          , address: addr
          , source: src
          , verses
          , selected: Set.empty
          , editingAddress: false
          , editingSource: false
          }
    H.put st
      { pericopes = A.snoc st.pericopes pericope
      , nextId = st.nextId + 1
      }

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
    P.DidDuplicate { id: baseId, as: _ } -> do
      st <- H.get
      case A.find (\q -> q.id == baseId) st.pericopes of
        Nothing -> pure unit
        Just p -> do
          let addr = p.address
              src  = p.source

          launchAff_ do
            res <- fetchVerses { address: addr, source: src }
            H.liftEffect case res of
              Left _ -> pure unit
              Right vs -> H.raise (AddPericope addr src vs)

    P.DidRemove rid ->
      H.modify_ \st -> st { pericopes = A.filter (\q -> q.id /= rid) st.pericopes }

    P.DidReorder _ ->
      -- Treat child drop as a request to drop current dragging onto this id
      handle (DropOn pid)

    P.DidUpdate updated ->
      H.modify_ \st -> st
        { pericopes = st.pericopes <#> \q -> if q.id == updated.id then updated else q }

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
