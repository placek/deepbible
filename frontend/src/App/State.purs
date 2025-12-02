module App.State where

import Data.Maybe (Maybe)

import Domain.Bible.Types (AiSearchResult, VerseSearchResult)
import Domain.Pericope.Types (Pericope, PericopeId)

type AppState =
  { pericopes :: Array Pericope
  , dragging :: Maybe PericopeId
  , droppingOver :: Maybe PericopeId
  , nextId :: Int
  , searchInput :: String
  , searchResults :: Array VerseSearchResult
  , aiSearchResults :: Array AiSearchResult
  , aiSearchEnabled :: Boolean
  , searchOpen :: Boolean
  , searchPerformed :: Boolean
  , searchLoading :: Boolean
  , aiSearchLoading :: Boolean
  , searchError :: Maybe String
  , aiSearchError :: Maybe String
  }
