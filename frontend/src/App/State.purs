module App.State where

import Data.Maybe (Maybe)

import Domain.Bible.Types (VerseSearchResult)
import Domain.Note.Types (Note)
import Domain.Pericope.Types (Pericope)
import Infrastructure.LocalStorage (SavedSheetEntry)

data Item
  = PericopeItem Pericope
  | NoteItem Note

type AppState =
  { items :: Array Item
  , dragging :: Maybe Int
  , droppingOver :: Maybe Int
  , sheetId :: String
  , title :: String
  , hydrating :: Boolean
  , nextId :: Int
  , searchInput :: String
  , searchResults :: Array VerseSearchResult
  , searchOpen :: Boolean
  , searchPerformed :: Boolean
  , searchLoading :: Boolean
  , searchError :: Maybe String
  , savedSheets :: Array SavedSheetEntry
  , sheetListOpen :: Boolean
  }
