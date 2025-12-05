module Pericope.Component (Query(..), Output(..), component, selectedAddressText) where

import Prelude

import Data.Array (catMaybes)
import Data.Array as A
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Newtype (unwrap)
import Data.Set as Set
import Data.String (Pattern(..), contains, joinWith, lastIndexOf, toLower, trim)
import Data.String.CodeUnits as CU
import Domain.Bible.Types (Address, Commentary(..), CrossReference(..), DictionaryEntry(..), Source, SourceInfo, Story(..), Verse(..),
                          VerseId)
import Domain.Pericope.Types (Pericope, PericopeId)
import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Infrastructure.Api (fetchCommentaries, fetchCrossReferences, fetchRenderedStories, fetchSources, fetchVerseDictionary, fetchVerses)
import Web.Event.Event (preventDefault, stopPropagation)
import Web.HTML.Event.DragEvent (DragEvent)
import Web.HTML.Event.DragEvent as DragEv
import Web.UIEvent.KeyboardEvent (key)
import Web.UIEvent.MouseEvent (MouseEvent, toEvent)

foreign import annotateCommentaryLinks :: Source -> String -> String

-- Child component for one pericope; it is Controlled by parent via Query/Output

data Query a
  = SetData Pericope a
  | Refresh a
  | CancelEditing a

data Output
  = DidDuplicate { id :: PericopeId }
  | DidRemove PericopeId
  | DidStartDrag PericopeId
  | DidDragOver PericopeId
  | DidDragLeave PericopeId
  | DidReorder { from :: PericopeId, to :: PericopeId }
  | DidUpdate Pericope
  | DidLoadCrossReference { source :: Source, address :: Address }
  | DidCreatePericopeFromSelection { source :: Source, address :: Address }
  | DidLoadStory { source :: Source, address :: Address }

type State =
  { pericope :: Pericope
  , editingAddress :: Boolean
  , editingSource :: Boolean
  , sources :: Maybe (Array SourceInfo)
  , originalAddress :: Maybe Address
  , originalSource :: Maybe Source
  , crossRefs :: CrossRefState
  , dictionary :: DictionaryState
  , activeDictionaryTopic :: Maybe String
  }

data CrossRefState
  = CrossRefsIdle
  | CrossRefsLoading
  | CrossRefsLoaded { references :: Array CrossReference, commentaries :: Array Commentary, stories :: Array Story }

data DictionaryState
  = DictionaryIdle
  | DictionaryLoading
  | DictionaryLoaded (Array DictionaryEntry)

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
      , dictionary: DictionaryIdle
      , activeDictionaryTopic: Nothing
      }
  , render
  , eval: H.mkEval $ H.defaultEval
      { handleAction = handle
      , handleQuery = handleQuery
      , receive = Just <<< Receive
      }
  }

-- Local actions
data Action
  = Noop
  | HandlePericopeClick MouseEvent
  | HandleAddressClick MouseEvent
  | HandleSourceClick MouseEvent
  | HandleSelectedAddressClick MouseEvent
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
  | Duplicate
  | DragStart DragEvent
  | DragOver DragEvent
  | DragLeave DragEvent
  | Drop DragEvent
  | Receive Pericope
  | OpenCrossReference Address
  | OpenStory { source :: Source, address :: Address }
  | ToggleDictionaryTopic MouseEvent String

render :: forall m. State -> H.ComponentHTML Action () m
render st =
  let
    addressText = selectedAddressText st.pericope

    addressNode =
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

    sourceNode =
      if st.editingSource then
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
                  filterValue = toLower st.pericope.source
                  filterPattern = Pattern filterValue
                  matchesFilter infoRec =
                    let
                      info = unwrap infoRec
                      haystack = toLower info.name <> " " <> toLower info.description_short
                    in
                    filterValue == "" || contains filterPattern haystack
                  filteredInfos = infos # A.filter matchesFilter
                in
                if A.null filteredInfos then
                  [ HH.div [ HP.class_ (HH.ClassName "source-empty") ]
                      [ HH.text "No sources match your search." ]
                  ]
                else
                  let
                    languages = Set.toUnfoldable (Set.fromFoldable (filteredInfos <#> (unwrap >>> _.language))) :: Array String
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
                        entries = filteredInfos # A.filter (\infoRec -> (unwrap infoRec).language == lang)
                        sorted = A.sortBy (comparing (unwrap >>> _.name)) entries
                      in
                      HH.div [ HP.class_ (HH.ClassName "source-language-group") ]
                        [ HH.h4 [ HP.class_ (HH.ClassName "source-language") ] [ HH.text lang ]
                        , HH.ul [ HP.class_ (HH.ClassName "source-options list-reset") ] (renderOption <$> sorted)
                        ]
                    sortedLanguages = A.sort languages
                  in
                  [ HH.div [ HP.class_ (HH.ClassName "source-list list") ] (renderGroup <$> sortedLanguages)
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

    renderSelectedAddress =
      [ HH.div
        [ HP.class_ (HH.ClassName "selected-address")
        , HE.onClick HandleSelectedAddressClick
        ]
        [ HH.text addressText ]
      ]

    renderDictionary =
      case st.dictionary of
        DictionaryIdle ->
          []
        DictionaryLoading ->
          []
        DictionaryLoaded entries ->
          if A.null entries then
            []
          else
            [ HH.div [ HP.class_ (HH.ClassName "dictionary") ]
                (renderDictionaryEntry <$> entries)
            ]

    renderDictionaryEntry (DictionaryEntry entry) =
      let
        isActive = st.activeDictionaryTopic == Just entry.topic
        formsList =
          if A.null entry.forms then
            [ HH.li [ HP.class_ (HH.ClassName "dictionary-form-item empty") ] [ HH.text "—" ] ]
          else
            entry.forms <#> \form ->
              HH.li [ HP.class_ (HH.ClassName "dictionary-form-item") ]
                [ HH.text (trim form) ]
        tooltip =
          if isActive then
            [ HH.div [ HP.class_ (HH.ClassName "dictionary-tooltip") ]
                [ HH.div [ HP.class_ (HH.ClassName "dictionary-topic") ]
                    [ HH.text entry.topic ]
                , HH.div [ HP.class_ (HH.ClassName "dictionary-meaning") ]
                    [ HH.text entry.meaning ]
                , HH.div [ HP.class_ (HH.ClassName "dictionary-parse") ]
                    [ HH.text entry.parse ]
                , HH.div [ HP.class_ (HH.ClassName "dictionary-forms") ]
                    [ HH.span [ HP.class_ (HH.ClassName "dictionary-forms-label") ]
                        [ HH.text "Forms" ]
                    , HH.ul [ HP.class_ (HH.ClassName "dictionary-forms-list list-reset") ] formsList
                    ]
                ]
            ]
          else
            []
      in
      HH.div
        [ HP.class_ (HH.ClassName ("dictionary-entry" <> if isActive then " active" else "")) ]
        ( [ HH.button
              [ HP.class_ (HH.ClassName "dictionary-word")
              , HE.onClick \ev -> ToggleDictionaryTopic ev entry.topic
              ]
              [ HH.text entry.word ]
          ] <> tooltip
        )

    renderCrossRefs = case st.crossRefs of
      CrossRefsIdle ->
        [ HH.div [ HP.class_ (HH.ClassName "cross-references-empty") ]
            [ ]
        ]

      CrossRefsLoading ->
        [ HH.div [ HP.class_ (HH.ClassName "cross-references-loading") ]
            [ HH.text "Loading cross references..." ]
        ]
      CrossRefsLoaded payload ->
        let
          storyNodes =
            if A.null payload.stories then
              []
            else
              [ HH.div [ HP.class_ (HH.ClassName "stories") ]
                  (renderStory <$> payload.stories)
              ]
          crossReferenceNodes =
            if A.null payload.references then
              [ ]
            else
              [ HH.div [ HP.class_ (HH.ClassName "cross-references") ]
                  (renderRef <$> payload.references)
              ]
          commentaryNodes =
            if A.null payload.commentaries then
              []
            else
              [ HH.div [ HP.class_ (HH.ClassName "commentaries") ]
                  (renderCommentary <$> payload.commentaries)
              ]
        in
          storyNodes <> crossReferenceNodes <> commentaryNodes

    renderRef (CrossReference ref) =
      HH.div
        [ HP.class_ (HH.ClassName "cross-reference")
        , HE.onClick \_ -> OpenCrossReference ref.reference
        ]
        [ HH.text ref.reference ]

    renderCommentary (Commentary commentary) =
      HH.div
        [ HP.class_ (HH.ClassName "commentary")
        ]
        [ HH.span [ HP.class_ (HH.ClassName "commentary-marker") ]
            [ HH.text commentary.marker ]
        , HH.span
            [ HP.class_ (HH.ClassName "commentary-text")
            , HP.prop (HH.PropName "innerHTML") commentary.text
            ]
            []
        ]

    renderStory (Story story) =
      HH.div
        [ HP.class_ (HH.ClassName "story")
        ]
        [ HH.div [ HP.class_ (HH.ClassName "story-title") ] [ HH.text story.title ]
        , HH.a
            [ HP.class_ (HH.ClassName "story-address")
            , HP.href "javascript:void(0)"
            , HE.onClick \_ -> OpenStory { source: story.source, address: story.address }
            ]
            [ HH.text story.address ]
        ]
  in
  HH.div [ HP.class_ (HH.ClassName "pericope"), HE.onClick HandlePericopeClick ]
    [ HH.div
        [ HP.class_ (HH.ClassName "didascalia")
        , HP.draggable true
        , HE.onDragStart DragStart
        , HE.onDragLeave DragLeave
        , HE.onDragOver DragOver
        , HE.onDrop Drop
        ]
        [ HH.div [ HP.class_ (HH.ClassName "didascalia-handle-group") ]
            [ HH.div [ HP.class_ (HH.ClassName "didascalia-handle") ]
                [ HH.text "☰" ]
            , HH.button
                [ HP.class_ (HH.ClassName "didascalia-duplicate icon-button")
                , HP.title "duplicate pericope"
                , HE.onClick \_ -> Duplicate
                ]
                [ HH.text "⧉" ]
            , HH.button
                [ HP.class_ (HH.ClassName "didascalia-remove icon-button")
                , HP.title "remove pericope"
                , HE.onClick \_ -> Remove
                ]
                [ HH.text "✕" ]
            ]
        , addressNode
        , sourceNode
        ]

    , HH.div [ HP.class_ (HH.ClassName "textus") ]
        (st.pericope.verses <#> \(Verse v) ->
          let sel = Set.member v.verse_id st.pericope.selected in
          HH.div
            [ HP.class_ (HH.ClassName ("verse" <> if sel then " selected" else ""))
            , HP.attr (HH.AttrName "data-chapter") (show v.chapter)
            , HP.attr (HH.AttrName "data-verse") (show v.verse)
            , HP.prop (HH.PropName "innerHTML") v.text
            , HE.onClick \_ -> ToggleSelect v.verse_id
            ]
            []
        )

    , HH.div [ HP.class_ (HH.ClassName "margin") ] (renderSelectedAddress <> renderCrossRefs <> renderDictionary)
    ]

handle :: forall m. MonadAff m => Action -> H.HalogenM State Action () Output m Unit
handle = case _ of
  Noop ->
    pure unit

  HandlePericopeClick _ -> do
    cancelEdits

  HandleAddressClick ev -> do
    H.liftEffect $ stopPropagation (toEvent ev)
    H.modify_ \st ->
      st
        { editingAddress = true
        , originalAddress = Just st.pericope.address
        }

  HandleSourceClick ev -> do
    H.liftEffect $ stopPropagation (toEvent ev)
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

  HandleSelectedAddressClick ev -> do
    H.liftEffect $ stopPropagation (toEvent ev)
    st <- H.get
    let addressText = selectedAddressText st.pericope
    when (addressText /= "") do
      H.raise (DidCreatePericopeFromSelection { source: st.pericope.source, address: addressText })

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
        , originalSource = Nothing
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
          nextDictionaryState = if Set.size sel1 == 1 then DictionaryLoading else DictionaryIdle
        in
        st
          { pericope = st.pericope { selected = sel1 }
          , crossRefs = nextCrossRefState
          , dictionary = nextDictionaryState
          , activeDictionaryTopic = Nothing
          }
      st <- H.get
      H.raise (DidUpdate st.pericope)
      let selectedIds :: Array VerseId
          selectedIds = Set.toUnfoldable st.pericope.selected
      case selectedIds of
        [only] -> do
          let
            selectedVerse = A.find (\(Verse v) -> v.verse_id == only) st.pericope.verses
            stillSelected verse = do
              st' <- H.get
              pure (Set.size st'.pericope.selected == 1 && Set.member verse st'.pericope.selected)
          case selectedVerse of
            Nothing -> pure unit
            Just (Verse v) -> do
              dictionaryRes <- H.liftAff $ fetchVerseDictionary only
              stillAfterDictionary <- stillSelected only
              when stillAfterDictionary do
                let dictionaryEntries = case dictionaryRes of
                      Left _ -> []
                      Right entries -> entries
                H.modify_ _
                  { dictionary = DictionaryLoaded dictionaryEntries
                  , activeDictionaryTopic = Nothing
                  }
              refsRes <- H.liftAff $ fetchCrossReferences only
              stillAfterRefs <- stillSelected only
              when stillAfterRefs do
                commRes <- H.liftAff $ fetchCommentaries only
                stillAfterCommentaries <- stillSelected only
                when stillAfterCommentaries do
                  storiesRes <- H.liftAff $ fetchRenderedStories v.source v.address
                  stillAfterStories <- stillSelected only
                  when stillAfterStories do
                    let
                      refs = case refsRes of
                        Left _ -> []
                        Right fetchedRefs -> fetchedRefs
                      commentaries = case commRes of
                        Left _ -> []
                        Right fetchedCommentaries -> annotateCommentary v.source <$> fetchedCommentaries
                      stories = case storiesRes of
                        Left _ -> []
                        Right fetchedStories -> fetchedStories
                    H.modify_ _
                      { crossRefs = CrossRefsLoaded { references: refs, commentaries, stories }
                      }
        _ -> pure unit

  Remove -> do
    st <- H.get
    H.raise (DidRemove st.pericope.id)

  Duplicate -> do
    st <- H.get
    H.raise (DidDuplicate { id: st.pericope.id })

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
    H.modify_ \st ->
      let
        shouldCloseSource = st.editingSource && p.source == st.pericope.source
        shouldResetSelection = Set.isEmpty p.selected
        nextCrossRefs =
          if shouldResetSelection then CrossRefsIdle else st.crossRefs
        nextDictionary =
          if shouldResetSelection then DictionaryIdle else st.dictionary
        nextTopic =
          if shouldResetSelection then Nothing else st.activeDictionaryTopic
      in
      st
        { pericope = p
        , crossRefs = nextCrossRefs
        , dictionary = nextDictionary
        , activeDictionaryTopic = nextTopic
        , editingSource = if shouldCloseSource then false else st.editingSource
        , originalSource = if shouldCloseSource then Nothing else st.originalSource
        }

  OpenCrossReference address -> do
    st <- H.get
    H.raise (DidLoadCrossReference { source: st.pericope.source, address })

  OpenStory payload -> do
    H.raise (DidLoadStory payload)

  ToggleDictionaryTopic ev topic -> do
    H.liftEffect $ stopPropagation (toEvent ev)
    H.modify_ \st ->
      let
        next =
          if st.activeDictionaryTopic == Just topic then Nothing else Just topic
      in
      st { activeDictionaryTopic = next }

handleQuery
  :: forall a m
   . MonadAff m
  => Query a
  -> H.HalogenM State Action () Output m (Maybe a)
handleQuery = case _ of
  SetData p a -> do
    H.modify_ _ { pericope = p }
    pure (Just a)
  Refresh a -> do
    st <- H.get
    launchFetch st.pericope.address st.pericope.source
    pure (Just a)
  CancelEditing a -> do
    cancelEdits
    pure (Just a)

cancelEdits :: forall m. MonadAff m => H.HalogenM State Action () Output m Unit
cancelEdits = do
  st <- H.get
  when st.editingAddress do
    handle CancelAddressEdit
  when st.editingSource do
    handle CancelSourceEdit

annotateCommentary :: Source -> Commentary -> Commentary
annotateCommentary source (Commentary commentary) =
  Commentary commentary { text = annotateCommentaryLinks source commentary.text }

launchFetch :: forall m. MonadAff m => Address -> Source -> H.HalogenM State Action () Output m Unit
launchFetch address source = do
  res <- H.liftAff $ fetchVerses address source
  case res of
    Left _  -> pure unit
    Right vs -> do
      H.modify_ \st -> st
        { pericope = st.pericope { verses = vs, selected = Set.empty }
        , crossRefs = CrossRefsIdle
        , dictionary = DictionaryIdle
        , activeDictionaryTopic = Nothing
        }
      st' <- H.get
      H.raise (DidUpdate st'.pericope)

selectedAddressText :: Pericope -> String
selectedAddressText pericope =
  let
    selectedAddresses =
      catMaybes $ pericope.verses <#> \(Verse v) ->
        if Set.member v.verse_id pericope.selected then Just v else Nothing

    renderSelection arr =
      case A.uncons arr of
        Nothing -> []
        Just { head, tail } ->
          let
            verses = A.cons head tail <#> _.verse
            ranges = renderRanges verses
            prefix = addressPrefix head.address
          in
          case A.uncons ranges of
            Nothing -> []
            Just { head: firstRange, tail: restRanges } ->
              A.cons (prefix <> firstRange) restRanges
  in
  joinWith "." (renderSelection selectedAddresses)

addressPrefix :: Address -> String
addressPrefix address =
  case lastIndexOf (Pattern ",") address of
    Just ix -> CU.take (ix + 1) address
    Nothing -> ""

renderRanges :: Array Int -> Array String
renderRanges arr =
  case A.uncons arr of
    Nothing -> []
    Just { head, tail } -> go head head tail
  where
  go start prev rest =
    case A.uncons rest of
      Nothing -> [formatRange start prev]
      Just { head: x, tail: xs }
        | x == prev + 1 -> go start x xs
        | otherwise -> A.cons (formatRange start prev) (go x x xs)

formatRange :: Int -> Int -> String
formatRange start end
  | start == end = show start
  | otherwise = show start <> "-" <> show end
