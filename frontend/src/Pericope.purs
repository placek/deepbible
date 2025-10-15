module Pericope (Query(..), Output(..), component) where

import Prelude

import Api (fetchCrossReferences, fetchSources, fetchVerses)
import Data.Array (catMaybes)
import Data.Array as A
import Data.Either (Either(..))
import Data.Foldable (intercalate)
import Data.Maybe (Maybe(..))
import Data.Set as Set
import Data.Newtype (unwrap)
import Web.UIEvent.MouseEvent (MouseEvent, ctrlKey, toEvent)
import Web.HTML.Event.DragEvent (DragEvent)
import Web.HTML.Event.DragEvent as DragEv
import Web.Event.Event (preventDefault, stopPropagation)
import Web.UIEvent.KeyboardEvent (key)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Effect.Aff.Class (class MonadAff)

import Types (Pericope, PericopeId, Verse(..), Address, Source, SourceInfo, CrossReference(..), VerseId)

-- Child component for one pericope; it is Controlled by parent via Query/Output

data Query a
  = SetData Pericope a
  | Refresh a

data Output
  = DidDuplicate { id :: PericopeId }
  | DidRemove PericopeId
  | DidStartDrag PericopeId
  | DidDragOver PericopeId
  | DidDragLeave PericopeId
  | DidReorder { from :: PericopeId, to :: PericopeId }
  | DidUpdate Pericope
  | DidLoadCrossReference { source :: Source, address :: Address }

type State =
  { pericope :: Pericope
  , editingAddress :: Boolean
  , editingSource :: Boolean
  , sources :: Maybe (Array SourceInfo)
  , originalAddress :: Maybe Address
  , originalSource :: Maybe Source
  , crossRefs :: CrossRefState
  }

data CrossRefState
  = CrossRefsIdle
  | CrossRefsLoading
  | CrossRefsLoaded (Array CrossReference)

component :: forall m. MonadAff m => H.Component Query Pericope Output m
component = H.mkComponent
  { initialState: \p ->
      { pericope: p
      , editingAddress: false
      , editingSource: false
      , sources: Nothing
      , originalAddress: Nothing
      , originalSource: Nothing
      , crossRefs: CrossRefsIdle
      }
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
  | CancelAddressEdit
  | CancelSourceEdit
  | CloseSourceList
  | SelectSource Source
  | Remove
  | DragStart DragEvent
  | DragOver DragEvent
  | DragLeave DragEvent
  | Drop DragEvent
  | Receive Pericope
  | OpenCrossReference Address

render :: forall m. State -> H.ComponentHTML Action () m
render st =
  let
    selectedAddresses =
      catMaybes $ st.pericope.verses <#> \(Verse v) ->
        if Set.member v.verse_id st.pericope.selected then Just v.address else Nothing
    addressText =
      case selectedAddresses of
        [] -> ""
        xs -> intercalate "; " xs
  in
  HH.div [ HP.class_ (HH.ClassName "pericope") ]
    [ HH.div
        [ HP.class_ (HH.ClassName "didascalia")
        , HP.draggable true
        , HE.onClick \_ -> Remove
        , HE.onDragStart DragStart
        , HE.onDragLeave DragLeave
        , HE.onDragOver DragOver
        , HE.onDrop Drop
        ]
        [
          if st.editingAddress then
            HH.div
              [ HP.class_ (HH.ClassName "address editing")
              , HE.onClick SwallowDidascaliaClick
              ]
              [ HH.input
                  [ HP.value st.pericope.address
                  , HE.onValueInput SetAddress
                  , HE.onKeyDown \ke -> case key ke of
                      "Enter" -> SubmitAddress
                      "Escape" -> CancelAddressEdit
                      _ -> Noop
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
            let
              sourceList = case st.sources of
                Nothing ->
                  [ HH.div [ HP.class_ (HH.ClassName "source-loading") ]
                      [ HH.text "Loading sources..." ]
                  ]
                Just infos ->
                  if A.null infos then
                    [ HH.div [ HP.class_ (HH.ClassName "source-empty") ]
                        [ HH.text "Unable to load sources." ]
                    ]
                  else
                    let
                      languages = Set.toUnfoldable (Set.fromFoldable (infos <#> (unwrap >>> _.language))) :: Array String
                      renderOption infoRec =
                        let
                          info = unwrap infoRec
                          isActive = info.name == st.pericope.source
                          cls = "source-option" <> if isActive then " active" else ""
                        in
                        HH.li
                          [ HP.class_ (HH.ClassName cls)
                          , HE.onClick \_ -> SelectSource info.name
                          ]
                          [ HH.div [ HP.class_ (HH.ClassName "source-option-name") ] [ HH.text info.name ]
                          , HH.div [ HP.class_ (HH.ClassName "source-option-description") ] [ HH.text info.description_short ]
                          ]
                      renderGroup lang =
                        let
                          entries = infos # A.filter (\infoRec -> (unwrap infoRec).language == lang)
                          sorted = A.sortBy (comparing (unwrap >>> _.name)) entries
                        in
                        HH.div [ HP.class_ (HH.ClassName "source-language-group") ]
                          [ HH.h4 [ HP.class_ (HH.ClassName "source-language") ] [ HH.text lang ]
                          , HH.ul [ HP.class_ (HH.ClassName "source-options") ] (renderOption <$> sorted)
                          ]
                      sortedLanguages = A.sort languages
                    in
                    [ HH.div [ HP.class_ (HH.ClassName "source-list") ] (renderGroup <$> sortedLanguages)
                    ]
            in
            HH.div
              [ HP.class_ (HH.ClassName "source editing")
              , HE.onClick SwallowDidascaliaClick
              ]
              ([ HH.input
                    [ HP.value st.pericope.source
                    , HE.onValueInput SetSource
                    , HP.autofocus true
                    , HE.onKeyDown \ke ->
                        case key ke of
                          "Enter" -> SubmitSource
                          "Escape" -> CloseSourceList
                          _ -> Noop
                    ]
                ] <> sourceList)
          else
            HH.div
              [ HP.class_ (HH.ClassName "source")
              , HE.onClick HandleSourceClick
              ]
              [ HH.text st.pericope.source ]
        , HH.div
            [ HP.class_ (HH.ClassName "selected-address") ]
            [ HH.text addressText ]
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
    , let
        renderCrossRefs = case st.crossRefs of
          CrossRefsIdle ->
              [ HH.div [ HP.class_ (HH.ClassName "cross-references-empty") ]
                  [  ]
              ]

          CrossRefsLoading ->
            [ HH.div [ HP.class_ (HH.ClassName "cross-references-loading") ]
                [ HH.text "Loading cross references..." ]
            ]
          CrossRefsLoaded refs ->
            if A.null refs then
              [ HH.div [ HP.class_ (HH.ClassName "cross-references-empty") ]
                  [  ]
              ]
            else
              [ HH.ul [ HP.class_ (HH.ClassName "cross-references") ]
                  (renderRef <$> refs)
              ]
        renderRef (CrossReference ref) =
          HH.li
            [ HP.class_ (HH.ClassName "cross-reference")
            , HE.onClick \_ -> OpenCrossReference ref.address
            ]
            [ HH.text ref.reference ]
      in
      HH.div [ HP.class_ (HH.ClassName "margin") ] renderCrossRefs
    ]

handle :: forall m. MonadAff m => Action -> H.HalogenM State Action () Output m Unit
handle = case _ of
  Noop ->
    pure unit

  HandleAddressClick ev -> do
    H.liftEffect $ stopPropagation (toEvent ev)
    if ctrlKey ev then do
      st <- H.get
      H.raise (DidDuplicate { id: st.pericope.id })
    else
      H.modify_ \st ->
        st
          { editingAddress = true
          , originalAddress = Just st.pericope.address
          }

  HandleSourceClick ev -> do
    H.liftEffect $ stopPropagation (toEvent ev)
    if ctrlKey ev then do
      st <- H.get
      H.raise (DidDuplicate { id: st.pericope.id })
    else do
      H.modify_ \st ->
        st
          { editingSource = true
          , originalSource = Just st.pericope.source
          }
      st <- H.get
      case st.sources of
        Just _ -> pure unit
        Nothing -> do
          res <- H.liftAff fetchSources
          case res of
            Left _ -> H.modify_ _ { sources = Just [] }
            Right srcs -> H.modify_ _ { sources = Just srcs }

  SwallowDidascaliaClick ev ->
    H.liftEffect $ stopPropagation (toEvent ev)

  SetAddress a ->
    H.modify_ \st -> st { pericope = st.pericope { address = a } }

  SetSource s ->
    H.modify_ \st -> st { pericope = st.pericope { source  = s } }

  SubmitAddress -> do
    st <- H.get
    H.modify_ _
      { editingAddress = false
      , originalAddress = Nothing
      }
    launchFetch st.pericope.address st.pericope.source

  CloseSourceList ->
    H.modify_ _ { editingSource = false }

  SubmitSource -> do
    st <- H.get
    H.modify_ _
      { editingSource = false
      , originalSource = Nothing
      }
    launchFetch st.pericope.address st.pericope.source

  CancelAddressEdit ->
    H.modify_ \st ->
      case st.originalAddress of
        Just orig ->
          st
            { editingAddress = false
            , originalAddress = Nothing
            , pericope = st.pericope { address = orig }
            }
        Nothing ->
          st
            { editingAddress = false
            , originalAddress = Nothing
            }

  CancelSourceEdit ->
    H.modify_ \st ->
      case st.originalSource of
        Just orig ->
          st
            { editingSource = false
            , originalSource = Nothing
            , pericope = st.pericope { source = orig }
            }
        Nothing ->
          st
            { editingSource = false
            , originalSource = Nothing
            }
  SelectSource newSource -> do
    H.modify_ \st ->
      st
        { pericope = st.pericope { source = newSource }
        , editingSource = false
        }
    st <- H.get
    launchFetch st.pericope.address newSource

  ToggleSelect vid ->
    do
      H.modify_ \st ->
        let
          sel0 = st.pericope.selected
          sel1 =
            if Set.member vid sel0 then Set.delete vid sel0 else Set.insert vid sel0
          nextCrossRefState = if Set.size sel1 == 1 then CrossRefsLoading else CrossRefsIdle
        in
        st
          { pericope = st.pericope { selected = sel1 }
          , crossRefs = nextCrossRefState
          }
      st <- H.get
      let selectedIds :: Array VerseId
          selectedIds = Set.toUnfoldable st.pericope.selected
      case selectedIds of
        [only] -> do
          res <- H.liftAff $ fetchCrossReferences only
          st' <- H.get
          if Set.size st'.pericope.selected == 1 && Set.member only st'.pericope.selected then
            case res of
              Left _ -> H.modify_ _ { crossRefs = CrossRefsLoaded [] }
              Right refs -> H.modify_ _ { crossRefs = CrossRefsLoaded refs }
          else
            pure unit
        _ -> pure unit

  Remove -> do
    st <- H.get
    H.raise (DidRemove st.pericope.id)

  DragStart ev -> do
    H.liftEffect $ stopPropagation (DragEv.toEvent ev)
    st <- H.get
    H.raise (DidStartDrag st.pericope.id)

  DragOver ev -> do
    H.liftEffect do
      preventDefault (DragEv.toEvent ev)
      stopPropagation (DragEv.toEvent ev)
    st <- H.get
    H.raise (DidDragOver st.pericope.id)

  DragLeave _ -> do
    st <- H.get
    H.raise (DidDragLeave st.pericope.id)

  Drop ev -> do
    H.liftEffect do
      preventDefault (DragEv.toEvent ev)
      stopPropagation (DragEv.toEvent ev)
    st <- H.get
    H.raise (DidReorder { from: st.pericope.id, to: st.pericope.id }) -- parent interprets drop target

  Receive p ->
    H.modify_ \st -> st { pericope = p, crossRefs = CrossRefsIdle }

  OpenCrossReference address -> do
    st <- H.get
    H.raise (DidLoadCrossReference { source: st.pericope.source, address })

launchFetch :: forall m. MonadAff m => Address -> Source -> H.HalogenM State Action () Output m Unit
launchFetch address source = do
  res <- H.liftAff $ fetchVerses address source
  case res of
    Left _  -> pure unit
    Right vs -> do
      H.modify_ \st -> st
        { pericope = st.pericope { verses = vs, selected = Set.empty }
        , crossRefs = CrossRefsIdle
        }
      st' <- H.get
      H.raise (DidUpdate st'.pericope)
