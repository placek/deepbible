module Domain.Bible.Types where

import Prelude

import Data.Argonaut (class DecodeJson, decodeJson, (.:), (.:?))
import Data.String (Pattern(..), Replacement(..), replace)
import Data.Maybe (fromMaybe)
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

newtype AiSearchResult =
  AiSearchResult
    { address :: Address
    , explanation :: String
    }
derive instance newtypeAiSearchResult :: Newtype AiSearchResult _

newtype AiSearchResponse =
  AiSearchResponse
    { output :: Array AiSearchResult }

derive instance newtypeAiSearchResponse :: Newtype AiSearchResponse _

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

newtype DictionaryEntry =
  DictionaryEntry
    { topic :: String
    , word :: String
    , meaning :: String
    , parse :: String
    , forms :: Array String
    }

derive instance newtypeDictionaryEntry :: Newtype DictionaryEntry _

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
    description_short <- do
      maybeDescription <- obj .:? "description_short"
      pure $ fromMaybe "" maybeDescription
    language <- do
      maybeLanguage <- obj .:? "language"
      pure $ fromMaybe "unknown" maybeLanguage
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

instance decodeDictionaryEntry :: DecodeJson DictionaryEntry where
  decodeJson j = do
    obj <- decodeJson j
    topic <- obj .:? "topic"
    word <- obj .:? "word"
    meaning <- obj .:? "meaning"
    parse <- obj .:? "parse"
    forms <- obj .:? "forms"
    pure $ DictionaryEntry
      { topic: fromMaybe "" topic
      , word: fromMaybe "" word
      , meaning: fromMaybe "" meaning
      , parse: fromMaybe "" parse
      , forms: fromMaybe [] forms
      }

instance decodeVerseSearchResult :: DecodeJson VerseSearchResult where
  decodeJson j = do
    obj <- decodeJson j
    address <- obj .: "address"
    source <- obj .: "source"
    text <- obj .: "text"
    pure $ VerseSearchResult { address, source, text }

instance decodeAiSearchResult :: DecodeJson AiSearchResult where
  decodeJson j = do
    obj <- decodeJson j
    rawAddress <- obj .: "address"
    let address = replace (Pattern ":") (Replacement ",") rawAddress
    explanation <- obj .: "explanation"
    pure $ AiSearchResult { address, explanation }

instance decodeAiSearchResponse :: DecodeJson AiSearchResponse where
  decodeJson j = do
    obj <- decodeJson j
    output <- obj .: "output"
    pure $ AiSearchResponse { output }

instance showVerse :: Show Verse where
  show (Verse { verse_id, text }) =
    "Verse { verse_id: " <> show verse_id <> ", text: " <> show text <> " }"
