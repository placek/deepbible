module Api where

import Prelude

import Affjax.Web (driver)
import Affjax as AX
import Affjax.RequestBody as RB
import Affjax.ResponseFormat as RF
import Data.Argonaut.Core (fromString)
import Data.Argonaut ((:=), (~>), jsonEmptyObject, decodeJson)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Effect.Aff (Aff)

import Types (Verse, Address, Source, SourceInfo, VerseId, CrossReference)

baseUrl :: String
baseUrl = "https://api.bible.placki.cloud"

fetchVerses :: Address -> Source -> Aff (Either String (Array Verse))
fetchVerses address source = do
  let
    url = baseUrl <> "/rpc/verses_by_address"
    payload = ("p_address" := fromString address) ~> ("p_source" := fromString source) ~> jsonEmptyObject
  res <- AX.post driver RF.json url $ Just (RB.json payload)
  case res of
    Left err -> pure $ Left ("HTTP error: " <> AX.printError err)
    Right json -> case decodeJson json.body of
      Left _ -> pure $ Left $ "Failed to fetch verses: " <> address
      Right verses -> pure $ Right verses

fetchSources :: Aff (Either String (Array SourceInfo))
fetchSources = do
  let url = baseUrl <> "/_all_sources"
  res <- AX.get driver RF.json url
  case res of
    Left err -> pure $ Left ("HTTP error: " <> AX.printError err)
    Right json -> case decodeJson json.body of
      Left _ -> pure $ Left "Failed to fetch sources"
      Right sources -> pure $ Right sources

fetchCrossReferences :: VerseId -> Aff (Either String (Array CrossReference))
fetchCrossReferences verseId = do
  let
    url = baseUrl <> "/rpc/cross_references"
    payload = ("p_verse_id" := fromString verseId) ~> jsonEmptyObject
  res <- AX.post driver RF.json url $ Just (RB.json payload)
  case res of
    Left err -> pure $ Left ("HTTP error: " <> AX.printError err)
    Right json -> case decodeJson json.body of
      Left _ -> pure $ Left $ "Failed to fetch cross references: " <> verseId
      Right refs -> pure $ Right refs
