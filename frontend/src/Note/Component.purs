module Note.Component (Query(..), Output(..), component) where

import Prelude

import Effect.Aff.Class (class MonadAff)
import Data.Maybe (Maybe(..))
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Note.Markdown (markdownToHtml)
import Web.Event.Event (preventDefault, stopPropagation)
import Web.HTML.Event.DragEvent (DragEvent)
import Web.HTML.Event.DragEvent as DragEv
import Web.UIEvent.KeyboardEvent (KeyboardEvent)
import Web.UIEvent.KeyboardEvent as KeyboardEv

import Domain.Note.Types (Note, NoteId)

data Query a
  = SetData Note a

data Output
  = DidDuplicate { id :: NoteId }
  | DidRemove NoteId
  | DidStartDrag NoteId
  | DidDragOver NoteId
  | DidDragLeave NoteId
  | DidReorder { from :: NoteId, to :: NoteId }
  | DidUpdate Note

type State =
  { note :: Note
  , isEditing :: Boolean
  }

data Action
  = Noop
  | SetContent String
  | StartEditing
  | StopEditing
  | KeyDown KeyboardEvent
  | Duplicate
  | Remove
  | DragStart DragEvent
  | DragOver DragEvent
  | DragLeave DragEvent
  | Drop DragEvent
  | Receive Note

component :: forall m. MonadAff m => H.Component Query Note Output m
component = H.mkComponent
  { initialState: \note -> { note, isEditing: false }
  , render
  , eval: H.mkEval $ H.defaultEval
      { handleAction = handle
      , receive = Just <<< Receive
      , handleQuery = handleQuery
      }
  }

render :: forall m. State -> H.ComponentHTML Action () m
render st =
  HH.div [ HP.class_ (HH.ClassName "note") ]
    [ HH.div
        [ HP.class_ (HH.ClassName "didascalia")
        , HP.draggable true
        , HE.onDragStart DragStart
        , HE.onDragOver DragOver
        , HE.onDragLeave DragLeave
        , HE.onDrop Drop
        ]
        [ HH.div [ HP.class_ (HH.ClassName "didascalia-header") ]
            [ HH.div [ HP.class_ (HH.ClassName "didascalia-handle-group") ]
                [ HH.div [ HP.class_ (HH.ClassName "didascalia-handle") ] [ HH.text "☰" ]
                , HH.button
                    [ HP.class_ (HH.ClassName "note-duplicate icon-button")
                    , HP.title "duplicate note"
                    , HE.onClick \_ -> Duplicate
                    ]
                    [ HH.text "⧉" ]
                , HH.button
                    [ HP.class_ (HH.ClassName "note-remove icon-button")
                    , HP.title "remove note"
                    , HE.onClick \_ -> Remove
                    ]
                    [ HH.text "✕" ]
                ]
            , HH.div [ HP.class_ (HH.ClassName "note-title") ] [ HH.text "Note" ]
            ]
        ]
    , HH.div [ HP.class_ (HH.ClassName "textus") ]
        [ renderBody st ]
    , HH.div [ HP.class_ (HH.ClassName "margin") ] []
    ]

renderBody :: forall m. State -> H.ComponentHTML Action () m
renderBody st =
  if st.isEditing then
    HH.textarea
      [ HP.class_ (HH.ClassName "note-body")
      , HP.value st.note.content
      , HE.onValueInput SetContent
      , HE.onKeyDown KeyDown
      , HE.onBlur \_ -> StopEditing
      , HP.placeholder "Write a note..."
      , HP.autofocus true
      ]
  else
    HH.div
      [ HP.class_ (HH.ClassName "note-body note-render")
      , HP.prop (HH.PropName "innerHTML") (markdownToHtml st.note.content)
      , HP.attr (HH.AttrName "data-placeholder") "Write a note..."
      , HE.onClick \_ -> StartEditing
      ]
      []

handle :: forall m. MonadAff m => Action -> H.HalogenM State Action () Output m Unit
handle = case _ of
  Noop ->
    pure unit

  SetContent content -> do
    H.modify_ \st -> st { note = st.note { content = content } }
    st <- H.get
    H.raise (DidUpdate st.note)

  StartEditing ->
    H.modify_ _ { isEditing = true }

  StopEditing ->
    H.modify_ _ { isEditing = false }

  KeyDown ev -> do
    let key = KeyboardEv.key ev
    when (key == "Escape") do
      H.liftEffect $ preventDefault (KeyboardEv.toEvent ev)
      H.modify_ _ { isEditing = false }

  Duplicate -> do
    st <- H.get
    H.raise (DidDuplicate { id: st.note.id })

  Remove -> do
    st <- H.get
    H.raise (DidRemove st.note.id)

  DragStart ev -> do
    H.liftEffect $ stopPropagation (DragEv.toEvent ev)
    st <- H.get
    H.raise (DidStartDrag st.note.id)

  DragOver ev -> do
    H.liftEffect do
      preventDefault (DragEv.toEvent ev)
      stopPropagation (DragEv.toEvent ev)
    st <- H.get
    H.raise (DidDragOver st.note.id)

  DragLeave _ -> do
    st <- H.get
    H.raise (DidDragLeave st.note.id)

  Drop ev -> do
    H.liftEffect do
      preventDefault (DragEv.toEvent ev)
      stopPropagation (DragEv.toEvent ev)
    st <- H.get
    H.raise (DidReorder { from: st.note.id, to: st.note.id })

  Receive note -> do
    H.modify_ _ { note = note }

handleQuery
  :: forall a m
   . MonadAff m
  => Query a
  -> H.HalogenM State Action () Output m (Maybe a)
handleQuery = case _ of
  SetData note a -> do
    H.modify_ _ { note = note }
    pure (Just a)
