module Main where

import Prelude

import Api (fetchVerses)
import Data.Array as A
import Data.Either (Either(..))
import Data.Foldable (for_)
import Data.Maybe (Maybe(..), fromMaybe, isJust)
import Data.Set as Set
import Effect (Effect)
import Effect.Aff (Aff, launchAff_)
import Effect.Class (liftEffect)
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
component = H.mkComponent
  { initialState
  , render
  , eval: H.mkEval H.defaultEval { initialize = Just Initialize, handleAction = handle }
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

render :: AppState -> H.ComponentHTML Action ()
render st =
  HH.div_
    (st.pericopes <#> renderPericope st)

renderPericope :: AppState -> Pericope -> HH.HTML Action
renderPericope st p =
  HH.slot (p.id) unit (P.component) p (ChildMsg p.id)

handle :: Action -> H.HalogenM AppState Action () Void Unit
handle = case _ of
  Initialize -> do
    -- Optional: seed with two demo pericopes like your HTML example
    add "J 3,16-17" "NVUL"
    add "J 3,16-17" "PAU"
    where
    add addr src = launchAff_ do
      res <- fetchVerses { address: addr, source: src }
      H.liftEffect $ case res of
        Left _ -> pure unit
        Right vs -> H.raise (AddPericope addr src vs)
  AddPericope addr src verses -> do
    st <- H.get
    let pid = PericopeId st.nextId
        pericope =
          { id: pid
          , address: addr
          , source: src
          , verses
          , selected: Set.empty
          , editingAddress: false
          , editingSource: false
          }
    H.put st { pericopes = A.snoc st.pericopes pericope, nextId = st.nextId + 1 }

  StartDrag pid -> H.modify_ _ { dragging = Just pid }
  OverDrag pid -> H.modify_ _ { droppingOver = Just pid }
  LeaveDrag _ -> H.modify_ _ { droppingOver = Nothing }
  DropOn targetId -> do
    st <- H.get
    case st.dragging of
      Nothing -> pure unit
      Just fromId -> do
        let ps = reorder fromId targetId st.pericopes
        H.put st { pericopes = ps, dragging = Nothing, droppingOver = Nothing }

  ChildMsg pid out -> case out of
    P.DidDuplicate { id: baseId, as } -> do
      st <- H.get
      case A.find (_ . id >>> (_ == baseId)) st.pericopes of
        Nothing -> pure unit
        Just p -> do
          let (addr, src) = case as of
                "address" -> (p.address, p.source)
                _ -> (p.address, p.source)
          -- Duplicate pericope and focus editing on the clicked field
          launchAff_ do
            res <- fetchVerses { address: addr, source: src }
            H.liftEffect $ case res of
              Left _ -> pure unit
              Right vs -> H.raise (AddPericope addr src vs)

    P.DidRemove rid -> H.modify_ \st -> st { pericopes = A.filter (_.id /= rid) st.pericopes }

    P.DidReorder { from, to } -> do
      -- We treat child drop as a request to drop current dragging onto this id
      handle (DropOn pid)

    P.DidUpdate updated ->
      H.modify_ \st -> st
        { pericopes = st.pericopes <#> \p -> if p.id == updated.id then updated else p }

-- Reorder helper
reorder :: PericopeId -> PericopeId -> Array Pericope -> Array Pericope
reorder fromId toId arr =
  let fromIx = A.findIndex (_.id == fromId) arr
      toIx = A.findIndex (_.id == toId) arr
  in case { a: fromIx, b: toIx } of
    { a: Just i, b: Just j } ->
      let item = arr !! i
          arr' = A.deleteAt i arr # fromMaybe arr
      in A.insertAt j item arr' # fromMaybe arr'
    _ -> arr
