module Types where

import Prelude

import Data.Maybe (Maybe)
import Data.Newtype (class Newtype)
import Data.Set as Set
import Data.Argonaut (class DecodeJson, decodeJson, (.:))

type Address = String
type Source = String
type VerseId = String
type PericopeId = Int

newtype VerseSearchResult =
  VerseSearchResult
    { address :: Address
    , source :: Source
    , text :: String
    }
derive instance newtypeVerseSearchResult :: Newtype VerseSearchResult _

newtype SourceInfo =
  SourceInfo
    { name :: String
    , description_short :: String
    , language :: String
    }
derive instance newtypeSourceInfo :: Newtype SourceInfo _

newtype CrossReference =
  CrossReference
    { id :: String
    , address :: Address
    , reference :: String
    , rate :: Int
    }

derive instance newtypeCrossReference :: Newtype CrossReference _

newtype Commentary =
  Commentary
    { marker :: String
    , text :: String
    }

derive instance newtypeCommentary :: Newtype Commentary _

-- A verse as returned by /rpc/verses_by_address
newtype Verse =
  Verse
    { book_number :: Int
    , chapter :: Int
    , verse :: Int
    , verse_id :: VerseId
    , language :: String
    , source :: Source
    , address :: Address
    , text :: String
    }

derive instance newtypeVerse :: Newtype Verse _

instance decodeVerse :: DecodeJson Verse where
  decodeJson j = do
    obj <- decodeJson j
    book_number <- obj .: "book_number"
    chapter <- obj .: "chapter"
    verse <- obj .: "verse"
    verse_id <- obj .: "verse_id"
    language <- obj .: "language"
    source <- obj .: "source"
    address <- obj .: "address"
    text <- obj .: "text"
    pure $ Verse { book_number
                 , chapter
                 , verse
                 , verse_id
                 , language
                 , source
                 , address
                 , text
                 }

instance decodeSourceInfo :: DecodeJson SourceInfo where
  decodeJson j = do
    obj <- decodeJson j
    name <- obj .: "name"
    description_short <- obj .: "description_short"
    language <- obj .: "language"
    pure $ SourceInfo { name, description_short, language }

instance decodeCrossReference :: DecodeJson CrossReference where
  decodeJson j = do
    obj <- decodeJson j
    id <- obj .: "id"
    address <- obj .: "address"
    reference <- obj .: "reference"
    rate <- obj .: "rate"
    pure $ CrossReference { id, address, reference, rate }

instance decodeCommentary :: DecodeJson Commentary where
  decodeJson j = do
    obj <- decodeJson j
    marker <- obj .: "marker"
    text <- obj .: "text"
    pure $ Commentary { marker, text }

instance decodeVerseSearchResult :: DecodeJson VerseSearchResult where
  decodeJson j = do
    obj <- decodeJson j
    address <- obj .: "address"
    source <- obj .: "source"
    text <- obj .: "text"
    pure $ VerseSearchResult { address, source, text }

instance showVerse :: Show Verse where
  show (Verse { verse_id, text }) =
    "Verse { verse_id: " <> show verse_id <> ", text: " <> show text <> " }"

-- One pericope = didascalia (address + source) + list of verses

type Pericope =
  { id :: PericopeId
  , address :: Address
  , source :: Source
  , verses :: Array Verse
  , selected :: Set.Set VerseId
  }

-- App state = list of pericopes in order + dnd drag state
type AppState =
  { pericopes :: Array Pericope
  , dragging :: Maybe PericopeId
  , droppingOver :: Maybe PericopeId
  , nextId :: Int
  , helpOpen :: Boolean
  , searchInput :: String
  , searchResults :: Array VerseSearchResult
  , searchOpen :: Boolean
  , searchPerformed :: Boolean
  , searchLoading :: Boolean
  , searchError :: Maybe String
  }
