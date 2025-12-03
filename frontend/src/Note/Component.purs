module Note.Component (Query(..), Output(..), component) where

import Prelude

import Effect.Aff.Class (class MonadAff)
import Data.Maybe (Maybe(..))
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Web.Event.Event (preventDefault, stopPropagation)
import Web.HTML.Event.DragEvent (DragEvent)
import Web.HTML.Event.DragEvent as DragEv

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
  }

data Action
  = Noop
  | SetContent String
  | Duplicate
  | Remove
  | DragStart DragEvent
  | DragOver DragEvent
  | DragLeave DragEvent
  | Drop DragEvent
  | Receive Note

component :: forall m. MonadAff m => H.Component Query Note Output m
component = H.mkComponent
  { initialState: \note -> { note }
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
        [ HP.class_ (HH.ClassName "note-header")
        , HP.draggable true
        , HE.onDragStart DragStart
        , HE.onDragOver DragOver
        , HE.onDragLeave DragLeave
        , HE.onDrop Drop
        ]
        [ HH.div [ HP.class_ (HH.ClassName "note-title") ] [ HH.text "Note" ]
        , HH.div [ HP.class_ (HH.ClassName "note-actions") ]
            [ HH.button
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
        ]
    , HH.textarea
        [ HP.class_ (HH.ClassName "note-body")
        , HP.value st.note.content
        , HE.onValueInput SetContent
        , HP.placeholder "Write a note..."
        ]
    ]

handle :: forall m. MonadAff m => Action -> H.HalogenM State Action () Output m Unit
handle = case _ of
  Noop ->
    pure unit

  SetContent content -> do
    H.modify_ \st -> st { note = st.note { content = content } }
    st <- H.get
    H.raise (DidUpdate st.note)

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
