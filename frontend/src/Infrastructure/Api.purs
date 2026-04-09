module Infrastructure.Api where

import Prelude

import Affjax as AX
import Affjax.RequestBody as RB
import Affjax.RequestHeader as RH
import Affjax.ResponseFormat as RF
import Affjax.Web (driver)
import Data.Argonaut (class DecodeJson, (:=), decodeJson, jsonEmptyObject, (.:), (~>))
import Data.Argonaut.Core (Json, fromString)
import Data.Array as A
import Data.Either (Either(..))
import Data.HTTP.Method (Method(..))
import Data.Maybe (Maybe(..))
import Effect.Aff (Aff)

import Domain.Bible.Types (Address, Commentary, CrossReference, DictionaryEntry, Source, SourceInfo, Story, Verse, VerseId, VerseSearchResult)

newtype Sheet =
  Sheet
    { id :: String
    , sheetData :: Json
    }

instance decodeSheet :: DecodeJson Sheet where
  decodeJson j = do
    obj <- decodeJson j
    id <- obj .: "id"
    dataJson <- obj .: "data"
    pure $ Sheet { id, sheetData: dataJson }

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

fetchSheet :: String -> Aff (Either String (Maybe Json))
fetchSheet sheetId = do
  let
    url = baseUrl <> "/rpc/fetch_sheet"
    payload = ("p_id" := fromString sheetId) ~> jsonEmptyObject
  res <- postgrestPost url payload
  case res of
    Left err -> pure $ Left ("HTTP error: " <> AX.printError err)
    Right json -> case decodeJson json.body of
      Left _ -> pure $ Left "Failed to fetch sheet"
      Right sheets -> case A.head sheets of
        Nothing -> pure $ Right Nothing
        Just (Sheet sheet) -> pure $ Right (Just sheet.sheetData)

upsertSheet :: String -> Json -> Aff (Either String Unit)
upsertSheet sheetId dataJson = do
  let
    url = baseUrl <> "/rpc/upsert_sheet"
    payload = ("p_id" := fromString sheetId) ~> ("p_data" := dataJson) ~> jsonEmptyObject
  res <- postgrestPost url payload
  case res of
    Left err -> pure $ Left ("HTTP error: " <> AX.printError err)
    Right _ -> pure $ Right unit

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

fetchCrossReferences :: Address -> Source -> Aff (Either String (Array CrossReference))
fetchCrossReferences address source = do
  let
    url = baseUrl <> "/rpc/fetch_cross_references_by_address"
    payload = ("p_address" := fromString address) ~> ("p_source" := fromString source) ~> jsonEmptyObject
  res <- postgrestPost url payload
  case res of
    Left err -> pure $ Left ("HTTP error: " <> AX.printError err)
    Right json -> case decodeJson json.body of
      Left _ -> pure $ Left $ "Failed to fetch cross references: " <> address
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
