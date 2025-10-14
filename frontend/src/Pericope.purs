module Pericope (Query(..), Output(..), DuplicateWith, component) where

import Prelude

import Api (fetchVerses)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Set as Set
import Web.UIEvent.MouseEvent (MouseEvent, ctrlKey, toEvent)
import Web.Event.Event (stopPropagation)
import Web.UIEvent.KeyboardEvent (key)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Effect.Aff.Class (class MonadAff)

import Types (Pericope, PericopeId, Verse(..), Address, Source)

-- Child component for one pericope; it is Controlled by parent via Query/Output

data Query a
  = SetData Pericope a
  | Refresh a

data DuplicateWith = DAddr | DSrc

data Output
  = DidDuplicate { id :: PericopeId, as :: DuplicateWith }
  | DidRemove PericopeId
  | DidReorder { from :: PericopeId, to :: PericopeId }
  | DidUpdate Pericope

type State = { pericope :: Pericope, editingAddress :: Boolean, editingSource :: Boolean }

component :: forall m. MonadAff m => H.Component Query Pericope Output m
component = H.mkComponent
  { initialState: \p -> { pericope: p, editingAddress: false, editingSource: false }
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
  | Remove
  | DragStart
  | DragOver
  | DragLeave
  | Drop
  | Receive Pericope

render :: forall m. State -> H.ComponentHTML Action () m
render st =
  HH.div [ HP.class_ (HH.ClassName "pericope") ]
    [ HH.div
        [ HP.class_ (HH.ClassName "didascalia")
        , HP.draggable true
        , HE.onClick \_ -> Remove
        , HE.onDragStart \_ -> DragStart
        , HE.onDragLeave \_ -> DragLeave
        , HE.onDragOver \_ -> DragOver
        , HE.onDrop \_ -> Drop
        ]
        [ -- Address (click = edit; ctrl+click = duplicate)
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
            HH.div
              [ HP.class_ (HH.ClassName "source editing")
              , HE.onClick SwallowDidascaliaClick
              ]
              [ HH.input
                  [ HP.value st.pericope.source
                  , HE.onValueInput SetSource
                  , HE.onKeyDown \ke ->
                      if key ke == "Enter" then SubmitSource else Noop
                  ]
              ]
          else
            HH.div
              [ HP.class_ (HH.ClassName "source")
              , HE.onClick HandleSourceClick
              ]
              [ HH.text st.pericope.source ]
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
  Noop -> pure unit
  HandleAddressClick ev -> do
    H.liftEffect $ stopPropagation (toEvent ev)
    if ctrlKey ev then do
      st <- H.get
      H.raise (DidDuplicate { id: st.pericope.id, as: DAddr })
    else
      H.modify_ _ { editingAddress = true }
  HandleSourceClick ev -> do
    H.liftEffect $ stopPropagation (toEvent ev)
    if ctrlKey ev then do
      st <- H.get
      H.raise (DidDuplicate { id: st.pericope.id, as: DSrc })
    else
      H.modify_ _ { editingSource = true }
  SwallowDidascaliaClick ev ->
    H.liftEffect $ stopPropagation (toEvent ev)

  SetAddress a -> H.modify_ \st -> st { pericope = st.pericope { address = a } }
  SetSource  s -> H.modify_ \st -> st { pericope = st.pericope { source  = s } }

  SubmitAddress -> do
    st <- H.get
    H.modify_ _ { editingAddress = false }
    launchFetch st.pericope.address st.pericope.source

  SubmitSource -> do
    st <- H.get
    H.modify_ _ { editingSource = false }
    launchFetch st.pericope.address st.pericope.source

  ToggleSelect vid ->
    H.modify_ \st ->
      let sel0 = st.pericope.selected
          sel1 = if Set.member vid sel0 then Set.delete vid sel0 else Set.insert vid sel0
      in st { pericope = st.pericope { selected = sel1 } }

  Remove -> do
    st <- H.get
    H.raise (DidRemove st.pericope.id)

  DragStart -> pure unit
  DragOver  -> pure unit
  DragLeave -> pure unit
  Drop -> do
    st <- H.get
    H.raise (DidReorder { from: st.pericope.id, to: st.pericope.id }) -- parent interprets drop target
  Receive p -> H.modify_ \st -> st { pericope = p }

launchFetch :: forall m. MonadAff m => Address -> Source -> H.HalogenM State Action () Output m Unit
launchFetch address source = do
  res <- H.liftAff $ fetchVerses address source
  case res of
    Left _  -> pure unit
    Right vs -> do
      H.modify_ \st -> st { pericope = st.pericope { verses = vs } }
      st' <- H.get
      H.raise (DidUpdate st'.pericope)
