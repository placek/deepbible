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

import Types (Verse, Address, Source)

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
