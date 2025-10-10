module Pericope (Query(..), Output(..), component) where

import Prelude

import Api (fetchVerses)
import Data.Array as A
import Data.Either (Either(..))
import Data.Maybe (Maybe(..), fromMaybe, isJust)
import Data.Set as Set
import Effect.Aff (launchAff_)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Web.Event.Event (Event)
import Web.HTML.Event.DataTransfer (getData, setData)
import Web.UIEvent.KeyboardEvent (KeyboardEvent, ctrlKey)
import Types (Pericope, PericopeId(..), Verse(..))

-- Child component for one pericope; it is Controlled by parent via Query/Output

data Query a
  = SetData Pericope a
  | Refresh a

data Output
  = DidDuplicate { id :: PericopeId, as :: "address" | "source" }
  | DidRemove PericopeId
  | DidReorder { from :: PericopeId, to :: PericopeId }
  | DidUpdate Pericope

component :: H.Component HH.HTML Query Output Pericope
component = H.mkComponent
  { initialState: identity
  , render
  , eval: H.mkEval $ H.defaultEval { handleAction = handle, receive = Just <<< SetData }
  }

-- Local actions
data Action
  = ClickAddress Boolean -- ctrl?
  | ClickSource Boolean
  | ToggleSelect String -- verse_id
  | EditAddress
  | EditSource
  | SetAddress String
  | SetSource String
  | SubmitAddress
  | SubmitSource
  | Remove
  | DragStart
  | DragOver
  | DragLeave
  | Drop

render :: Pericope -> H.ComponentHTML Action ()
render st =
  HH.div [ HP.class_ (HH.ClassName "pericope") ]
    [ HH.div
        [ HP.class_ (HH.ClassName "didascalia")
        , HP.draggable true
        , HE.onClick \_ -> pure Remove
        , HE.onDragStart \e -> do
            pure DragStart
        , HE.onDragOver \e -> do
            e.preventDefault
            pure DragOver
        , HE.onDragLeave \_ -> pure DragLeave
        , HE.onDrop \e -> do
            e.preventDefault
            pure Drop
        ]
        [ -- Address (click = edit; ctrl+click = duplicate)
          if st.editingAddress then
            HH.div [ HP.class_ (HH.ClassName "address editing"), HE.onClick HE.stopPropagation ]
              [ HH.input
                  [ HP.value st.address
                  , HE.onValueInput SetAddress
                  , HE.onKeyDown \ke -> if ke.key == "Enter" then pure SubmitAddress else pure (HE.noop)
                  , HP.autofocus true
                  ]
              ]
          else
            HH.div [ HP.class_ (HH.ClassName "address")
                   , HE.onClick \ev -> do
                       ctrl <- ctrlKey ev
                       if ctrl then pure (ClickAddress true) else pure EditAddress
                   ]
                   [ HH.text st.address ]
        , if st.editingSource then
            HH.div [ HP.class_ (HH.ClassName "source editing"), HE.onClick HE.stopPropagation ]
              [ HH.input
                  [ HP.value st.source
                  , HE.onValueInput SetSource
                  , HE.onKeyDown \ke -> if ke.key == "Enter" then pure SubmitSource else pure (HE.noop)
                  ]
              ]
          else
            HH.div [ HP.class_ (HH.ClassName "source")
                   , HE.onClick \ev -> do
                       ctrl <- ctrlKey ev
                       if ctrl then pure (ClickSource true) else pure EditSource
                   ]
                   [ HH.text st.source ]
        ]
    , HH.div [ HP.class_ (HH.ClassName "textus") ]
        (st.verses <#> \(Verse v) ->
          let sel = Set.member v.verse_id st.selected in
          HH.div
            [ HP.class_ (HH.ClassName ("verse" <> if sel then " selected" else ""))
            , HP.attr (HH.AttrName "data-chapter") (show v.chapter)
            , HP.attr (HH.AttrName "data-verse") (show v.verse)
            , HE.onClick \ev -> do
                ev.stopPropagation
                pure (ToggleSelect v.verse_id)
            ]
            [ HH.text v.text ]
        )
    ]

handle :: Action -> H.HalogenM Pericope Action () Output Unit
handle = case _ of
  ClickAddress _ -> H.raise (DidDuplicate { id: _.id, as: "address" })
  ClickSource _ -> H.raise (DidDuplicate { id: _.id, as: "source" })
  EditAddress -> H.modify_ _ { editingAddress = true }
  EditSource -> H.modify_ _ { editingSource = true }
  SetAddress s -> H.modify_ _ { address = s }
  SetSource s -> H.modify_ _ { source = s }
  SubmitAddress -> do
    st <- H.get
    H.modify_ _ { editingAddress = false }
    launchFetch st.address st.source
  SubmitSource -> do
    st <- H.get
    H.modify_ _ { editingSource = false }
    launchFetch st.address st.source
  ToggleSelect vid -> H.modify_ \st -> st { selected =
    if Set.member vid st.selected then Set.delete vid st.selected else Set.insert vid st.selected }
  Remove -> do
    st <- H.get
    H.raise (DidRemove st.id)
  DragStart -> pure unit
  DragOver -> pure unit
  DragLeave -> pure unit
  Drop -> do
    st <- H.get
    H.raise (DidReorder { from: st.id, to: st.id }) -- parent interprets with drop target

launchFetch :: String -> String -> H.HalogenM Pericope Action () Output Unit
launchFetch address source = do
  st <- H.get
  H.subscribe_ $ H.eventSource \emit -> do
    launchAff_ do
      res <- fetchVerses { address, source }
      case res of
        Left _ -> pure unit
        Right vs -> emit (Right vs)
    pure mempty
  where
  -- consume the emitted verses by updating state and notifying parent
  handleVerses vs = do
    H.modify_ _ { verses = vs }
    st' <- H.get
    H.raise (DidUpdate st')
