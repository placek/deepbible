module App.State where

import Data.Array (mapMaybe)
import Data.Maybe (Maybe(..))

import Domain.Bible.Types (VerseSearchResult)
import Domain.Note.Types (Note)
import Domain.Pericope.Types (Pericope)

data Item
  = PericopeItem Pericope
  | NoteItem Note

pericopesFromItems :: Array Item -> Array Pericope
pericopesFromItems = mapMaybe case _ of
  PericopeItem p -> Just p
  NoteItem _ -> Nothing

type AppState =
  { items :: Array Item
  , dragging :: Maybe Int
  , droppingOver :: Maybe Int
  , nextId :: Int
  , searchInput :: String
  , searchResults :: Array VerseSearchResult
  , searchOpen :: Boolean
  , searchPerformed :: Boolean
  , searchLoading :: Boolean
  , searchError :: Maybe String
  }
