module Infrastructure.Api where

import Prelude

import Affjax as AX
import Affjax.RequestBody as RB
import Affjax.RequestHeader as RH
import Affjax.ResponseFormat as RF
import Affjax.Web (driver)
import Data.Argonaut ((:=), decodeJson, jsonEmptyObject, (~>))
import Data.Argonaut.Core (fromString)
import Data.Either (Either(..))
import Data.HTTP.Method (Method(..))
import Data.Maybe (Maybe(..))
import Effect.Aff (Aff)

import Domain.Bible.Types (Address, Commentary, CrossReference, DictionaryEntry, Source, SourceInfo, Story, Verse, VerseId, VerseSearchResult)

baseUrl :: String
baseUrl = "https://api.bible.placki.cloud"

postgrestHeaders :: Array RH.RequestHeader
postgrestHeaders =
  [ RH.RequestHeader "Accept-Profile" "api"
  , RH.RequestHeader "Content-Profile" "api"
  ]

postgrestGet url =
  AX.request driver $ AX.defaultRequest
    { url = url
    , headers = postgrestHeaders
    , responseFormat = RF.json
    }

postgrestPost url payload =
  AX.request driver $ AX.defaultRequest
    { method = Left POST
    , url = url
    , headers = postgrestHeaders
    , responseFormat = RF.json
    , content = Just (RB.json payload)
    }

fetchVerses :: Address -> Source -> Aff (Either String (Array Verse))
fetchVerses address source = do
  let
    url = baseUrl <> "/rpc/fetch_verses_by_address"
    payload = ("p_address" := fromString address) ~> ("p_source" := fromString source) ~> jsonEmptyObject
  res <- postgrestPost url payload
  case res of
    Left err -> pure $ Left ("HTTP error: " <> AX.printError err)
    Right json -> case decodeJson json.body of
      Left _ -> pure $ Left $ "Failed to fetch verses: " <> address
      Right verses -> pure $ Right verses

fetchSources :: Aff (Either String (Array SourceInfo))
fetchSources = do
  let
    -- Keep the select list minimal to avoid decoding failures.
    url = baseUrl <> "/rpc/_all_sources?select=name,description_short,language"
    payload = jsonEmptyObject
  res <- postgrestPost url payload
  case res of
    Left err -> pure $ Left ("HTTP error: " <> AX.printError err)
    Right json -> case decodeJson json.body of
      Left _ -> pure $ Left "Failed to fetch sources"
      Right sources -> pure $ Right sources

fetchCrossReferences :: VerseId -> Aff (Either String (Array CrossReference))
fetchCrossReferences verseId = do
  let
    url = baseUrl <> "/rpc/fetch_cross_references"
    payload = ("p_verse_id" := fromString verseId) ~> jsonEmptyObject
  res <- postgrestPost url payload
  case res of
    Left err -> pure $ Left ("HTTP error: " <> AX.printError err)
    Right json -> case decodeJson json.body of
      Left _ -> pure $ Left $ "Failed to fetch cross references: " <> verseId
      Right refs -> pure $ Right refs

fetchCommentaries :: VerseId -> Aff (Either String (Array Commentary))
fetchCommentaries verseId = do
  let
    url = baseUrl <> "/rpc/fetch_commentaries"
    payload = ("p_verse_id" := fromString verseId) ~> jsonEmptyObject
  res <- postgrestPost url payload
  case res of
    Left err -> pure $ Left ("HTTP error: " <> AX.printError err)
    Right json -> case decodeJson json.body of
      Left _ -> pure $ Left $ "Failed to fetch commentaries: " <> verseId
      Right commentaries -> pure $ Right commentaries

fetchRenderedStories :: Source -> Address -> Aff (Either String (Array Story))
fetchRenderedStories source address = do
  let
    url = baseUrl <> "/rpc/fetch_rendered_stories"
    payload = ("p_source" := fromString source) ~> ("p_address" := fromString address) ~> jsonEmptyObject
  res <- postgrestPost url payload
  case res of
    Left err -> pure $ Left ("HTTP error: " <> AX.printError err)
    Right json -> case decodeJson json.body of
      Left _ -> pure $ Left $ "Failed to fetch stories: " <> address
      Right stories -> pure $ Right stories

fetchVerseDictionary :: VerseId -> Aff (Either String (Array DictionaryEntry))
fetchVerseDictionary verseId = do
  let
    url = baseUrl <> "/rpc/verse_dictionary"
    payload = ("p_verse_id" := fromString verseId) ~> jsonEmptyObject
  res <- postgrestPost url payload
  case res of
    Left err -> pure $ Left ("HTTP error: " <> AX.printError err)
    Right json -> case decodeJson json.body of
      Left _ -> pure $ Left $ "Failed to fetch verse dictionary: " <> verseId
      Right entries -> pure $ Right entries

searchVerses :: String -> Aff (Either String (Array VerseSearchResult))
searchVerses query = do
  let
    url = baseUrl <> "/rpc/search_verses"
    payload = ("search_phrase" := query) ~> jsonEmptyObject
  res <- postgrestPost url payload
  case res of
    Left err -> pure $ Left ("HTTP error: " <> AX.printError err)
    Right json -> case decodeJson json.body of
      Left _ -> pure $ Left "Failed to search verses"
      Right verses -> pure $ Right verses
