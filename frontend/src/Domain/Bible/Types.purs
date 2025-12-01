module Domain.Bible.Types where

import Prelude

import Data.Argonaut (class DecodeJson, decodeJson, (.:))
import Data.Newtype (class Newtype)

-- Core domain primitives

type Address = String
type Source = String
type VerseId = String

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

newtype Story =
  Story
    { source :: Source
    , book :: String
    , title :: String
    , address :: Address
    , a :: Int
    , b :: Int
    }

derive instance newtypeStory :: Newtype Story _

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

instance decodeStory :: DecodeJson Story where
  decodeJson j = do
    obj <- decodeJson j
    source <- obj .: "source"
    book <- obj .: "book"
    title <- obj .: "title"
    address <- obj .: "address"
    a <- obj .: "a"
    b <- obj .: "b"
    pure $ Story { source, book, title, address, a, b }

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
