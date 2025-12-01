module Search where

import Prelude

import Api (fetchVerses, searchVerses)
import Data.Array as A
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Newtype (unwrap)
import Data.String.CodeUnits (fromCharArray, toCharArray)
import Data.String.CodeUnits as CU
import Data.String.Common (trim)
import Effect.Aff (Aff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import SearchHighlight (splitSearchInput, toMaybeColor)
import Types (AppState, Verse, VerseSearchResult)
import Web.Event.Event (stopPropagation)
import Web.UIEvent.KeyboardEvent (KeyboardEvent, key)
import Web.UIEvent.MouseEvent (MouseEvent, toEvent)

-- Actions specific to search functionality
-- Consumers should wrap these in their own action type.
data Action
  = UpdateSearchInput String
  | SubmitSearch
  | ReceiveSearchResults (Either String (Array VerseSearchResult))
  | SelectSearchResult VerseSearchResult
  | FocusSearchInput
  | CloseSearchResults
  | HandleSearchKey KeyboardEvent
  | SearchInputClick MouseEvent
  | SearchResultsClick MouseEvent

renderSearchSection
  :: forall parentAction slots
   . (Action -> parentAction)
  -> AppState
  -> H.ComponentHTML parentAction slots Aff
renderSearchSection toParentAction st =
  HH.div
    [ HP.class_ (HH.ClassName "search-section") ]
    ( [ HH.div
          [ HP.class_ (HH.ClassName "search-input-group") ]
              [ HH.div
                  [ HP.class_ (HH.ClassName "search-input-wrapper") ]
                  [ HH.div
                      [ HP.class_ (HH.ClassName "search-input-highlight")
                      , HP.attr (HH.AttrName "aria-hidden") "true"
                      ]
                      (renderSearchInputHighlights st.searchInput)
                  , HH.input
                      [ HP.class_ (HH.ClassName "search-input")
                      , HP.attr (HH.AttrName "type") "text"
                      , HP.placeholder "search verses, e.g. '@NVUL ~J 3,10- Deus'"
                      , HP.value st.searchInput
                      , HE.onValueInput (toParentAction <<< UpdateSearchInput)
                      , HE.onFocus \_ -> toParentAction FocusSearchInput
                      , HE.onClick (toParentAction <<< SearchInputClick)
                      , HE.onKeyDown (toParentAction <<< HandleSearchKey)
                      ]
                  ]
              ]
          ]
        <> renderSearchFeedback st
        <> renderSearchResults toParentAction st
    )

handleAction
  :: forall parentAction slots
   . (String -> String -> Array Verse -> H.HalogenM AppState parentAction slots Void Aff Unit)
  -> Action
  -> H.HalogenM AppState parentAction slots Void Aff Unit
handleAction insertPericope action = case action of
  UpdateSearchInput value ->
    H.modify_ \st -> st { searchInput = value }

  SubmitSearch -> do
    st <- H.get
    let query = trim st.searchInput
    if query == "" then
      pure unit
    else do
      H.modify_ \state -> state
        { searchInput = query
        , searchLoading = true
        , searchError = Nothing
        , searchOpen = true
        , searchPerformed = true
        , searchResults = []
        }
      res <- H.liftAff $ searchVerses query
      handleAction insertPericope (ReceiveSearchResults res)

  ReceiveSearchResults res -> case res of
    Left err ->
      H.modify_ \st -> st
        { searchLoading = false
        , searchError = Just err
        , searchResults = []
        }
    Right results ->
      H.modify_ \st -> st
        { searchLoading = false
        , searchError = Nothing
        , searchResults = results
        , searchOpen = true
        }

  SelectSearchResult result -> do
    let details = unwrap result
    H.modify_ \st -> st { searchOpen = false }
    res <- H.liftAff $ fetchVerses details.address details.source
    case res of
      Left _ -> pure unit
      Right verses -> insertPericope details.address details.source verses

  FocusSearchInput ->
    H.modify_ \st ->
      if st.searchPerformed || st.searchLoading || (case st.searchError of
            Just _ -> true
            Nothing -> false
         )
      then st { searchOpen = true }
      else st

  CloseSearchResults ->
    H.modify_ \st -> st { searchOpen = false }

  HandleSearchKey ev -> case key ev of
    "Enter" -> handleAction insertPericope SubmitSearch
    "Escape" -> handleAction insertPericope CloseSearchResults
    _ -> pure unit

  SearchInputClick ev -> do
    H.liftEffect $ stopPropagation (toEvent ev)
    handleAction insertPericope FocusSearchInput

  SearchResultsClick ev ->
    H.liftEffect $ stopPropagation (toEvent ev)

renderSearchFeedback :: forall action slots. AppState -> Array (H.ComponentHTML action slots Aff)
renderSearchFeedback st =
  let
    baseAttrs = [ HP.class_ (HH.ClassName "search-status") ]
  in case st.searchLoading, st.searchError of
       true, _ ->
         [ HH.div baseAttrs [ HH.text "Searching…" ] ]
       false, Just err ->
         [ HH.div baseAttrs [ HH.text err ] ]
       false, Nothing ->
         if st.searchPerformed && A.null st.searchResults then
           [ HH.div baseAttrs [ HH.text "No results" ] ]
         else
           []

renderSearchResults
  :: forall parentAction slots
   . (Action -> parentAction)
  -> AppState
  -> Array (H.ComponentHTML parentAction slots Aff)
renderSearchResults toParentAction st =
  if not st.searchOpen || A.null st.searchResults then
    []
  else
    [ HH.ul
        [ HP.class_ (HH.ClassName "search-results list list-reset")
        , HE.onClick (toParentAction <<< SearchResultsClick)
        ]
        (st.searchResults <#> renderSearchResult toParentAction)
    ]

renderSearchResult
  :: forall parentAction slots
   . (Action -> parentAction)
  -> VerseSearchResult
  -> H.ComponentHTML parentAction slots Aff
renderSearchResult toParentAction result =
  let
    details = unwrap result
  in
  HH.li
    [ HP.class_ (HH.ClassName "search-result")
    , HE.onClick \_ -> toParentAction (SelectSearchResult result)
    ]
    [ HH.div
        [ HP.class_ (HH.ClassName "search-result-meta") ]
        [ HH.div
            [ HP.class_ (HH.ClassName "search-result-address") ]
            [ HH.text ("~" <> details.address) ]
        , HH.div
            [ HP.class_ (HH.ClassName "search-result-source") ]
            [ HH.text ("@" <> details.source) ]
        ]
    , HH.div
        [ HP.class_ (HH.ClassName "search-result-text") ]
        [ HH.text (stripTags details.text) ]
    ]

renderSearchInputHighlights :: forall action slots. String -> Array (H.ComponentHTML action slots Aff)
renderSearchInputHighlights input =
  let
    segments = splitSearchInput input
  in
    if CU.length input == 0 then
      [ HH.span [ HP.class_ (HH.ClassName "search-input-placeholder") ] [ HH.text "" ] ]
    else
      segments <#> renderSegment
  where
  renderSegment segment =
    case toMaybeColor segment of
      Just "yellow" ->
        HH.span [ HP.class_ (HH.ClassName "search-token search-token--yellow") ] [ HH.text segment.text ]
      Just "red" ->
        HH.span [ HP.class_ (HH.ClassName "search-token search-token--red") ] [ HH.text segment.text ]
      _ -> HH.span_ [ HH.text segment.text ]

stripTags :: String -> String
stripTags = fromCharArray <<< go false <<< toCharArray
  where
  go :: Boolean -> Array Char -> Array Char
  go insideTag chars =
    case A.uncons chars of
      Nothing -> []
      Just { head: c, tail: cs }
        | c == '<' -> go true cs
        | c == '>' -> go false cs
        | insideTag -> go insideTag cs
        | otherwise -> A.cons c (go insideTag cs)
