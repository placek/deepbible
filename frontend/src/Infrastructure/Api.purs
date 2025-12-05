module Infrastructure.Api where

import Prelude

import Affjax as AX
import Affjax.RequestBody as RB
import Affjax.ResponseFormat as RF
import Affjax.Web (driver)
import Data.Argonaut ((:=), decodeJson, jsonEmptyObject, (~>))
import Data.Argonaut.Decode.Error (JsonDecodeError)
import Data.Argonaut.Core (fromString)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Effect.Aff (Aff)

import Domain.Bible.Types (Address, AiSearchResponse(..), AiSearchResult, Commentary, CrossReference, DictionaryEntry, Source, SourceInfo,
                          Story, Verse, VerseId, VerseSearchResult)

baseUrl :: String
baseUrl = "https://api.bible.placki.cloud"

aiExplainUrl :: String
aiExplainUrl = "https://n8n.placki.cloud/webhook/deepbible/ai-search"

aiStatusUrl :: String
aiStatusUrl = "https://n8n.placki.cloud/webhook/deepbible/status"

fetchVerses :: Address -> Source -> Aff (Either String (Array Verse))
fetchVerses address source = do
  let
    url = baseUrl <> "/rpc/fetch_verses_by_address"
    payload = ("p_address" := fromString address) ~> ("p_source" := fromString source) ~> jsonEmptyObject
  res <- AX.post driver RF.json url $ Just (RB.json payload)
  case res of
    Left err -> pure $ Left ("HTTP error: " <> AX.printError err)
    Right json -> case decodeJson json.body of
      Left _ -> pure $ Left $ "Failed to fetch verses: " <> address
      Right verses -> pure $ Right verses

fetchSources :: Aff (Either String (Array SourceInfo))
fetchSources = do
  let
    -- PostgREST requires an explicit select list; keep it minimal to avoid decoding failures.
    url = baseUrl <> "/_all_sources?select=name,description_short,language"
  res <- AX.get driver RF.json url
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
  res <- AX.post driver RF.json url $ Just (RB.json payload)
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
  res <- AX.post driver RF.json url $ Just (RB.json payload)
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
  res <- AX.post driver RF.json url $ Just (RB.json payload)
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
  res <- AX.post driver RF.json url $ Just (RB.json payload)
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
  res <- AX.post driver RF.json url $ Just (RB.json payload)
  case res of
    Left err -> pure $ Left ("HTTP error: " <> AX.printError err)
    Right json -> case decodeJson json.body of
      Left _ -> pure $ Left "Failed to search verses"
      Right verses -> pure $ Right verses

fetchAiExplanations :: String -> Maybe Source -> Aff (Either String (Array AiSearchResult))
fetchAiExplanations phrase maybeSource = do
  let
    payload =
      case maybeSource of
        Just source ->
          ("phrase" := fromString phrase)
            ~> ("source" := fromString source)
            ~> jsonEmptyObject
        Nothing ->
          ("phrase" := fromString phrase) ~> jsonEmptyObject
  res <- AX.post driver RF.json aiExplainUrl $ Just (RB.json payload)
  case res of
    Left err -> pure $ Left ("HTTP error: " <> AX.printError err)
    Right json -> case decodeJson json.body of
      Right explanations -> pure $ Right explanations
      Left _ -> case decodeJson json.body of
        Right (AiSearchResponse { output }) -> pure $ Right output
        Left _ -> pure $ Left "Failed to fetch AI explanations"

checkAiStatus :: Aff Boolean
checkAiStatus = do
  let
    payload = ("status" := fromString "up") ~> jsonEmptyObject
  res <- AX.post driver RF.json aiStatusUrl $ Just (RB.json payload)
  case res of
    Left _ -> pure false
    Right json -> case decodeJson json.body :: Either JsonDecodeError { status :: String } of
      Right { status }
        | status == "up" -> pure true
      _ -> pure false
