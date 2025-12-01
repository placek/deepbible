module App.State where

import Data.Maybe (Maybe)

import Domain.Bible.Types (VerseSearchResult)
import Domain.Pericope.Types (Pericope, PericopeId)

type AppState =
  { pericopes :: Array Pericope
  , dragging :: Maybe PericopeId
  , droppingOver :: Maybe PericopeId
  , nextId :: Int
  , searchInput :: String
  , searchResults :: Array VerseSearchResult
  , searchOpen :: Boolean
  , searchPerformed :: Boolean
  , searchLoading :: Boolean
  , searchError :: Maybe String
  }
