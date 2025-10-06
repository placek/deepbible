module Api where

import Prelude

import Affjax as AX
import Affjax.RequestBody as RB
import Affjax.ResponseFormat as RF
import Data.Argonaut (class DecodeJson, Json, decodeJson, jsonEmptyObject, (:=), (~>))
import Data.Argonaut.Core as J
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Effect.Aff (Aff)
import Types (Verse(..))

base :: String
base = "https://api.bible.placki.cloud"

instance decodeVerse :: DecodeJson Verse where
decodeJson =
J.caseJsonObject \obj -> do
book_number <- obj J..: "book_number"
chapter <- obj J..: "chapter"
verse <- obj J..: "verse"
verse_id <- obj J..: "verse_id"
language <- obj J..: "language"
source <- obj J..: "source"
address <- obj J..: "address"
text <- obj J..: "text"
pure $ Verse { book_number, chapter, verse, verse_id, language, source, address, text }
where
infixl 7 .:
(.:) = J.getField

fetchVerses :: { address :: String, source :: String } -> Aff (Either String (Array Verse))
fetchVerses { address, source } = do
let url = base <> "/rpc/verses_by_address"
payload =
("p_address" := J.fromString address)
~> ("p_source" := J.fromString source)
~> jsonEmptyObject
res <- AX.request
{ method: Left AX.POST
, url
, headers: [ AX.RequestHeader "Content-Type" "application/json" ]
, content: Just (RB.json payload)
, responseFormat: RF.json
}
case res.body of
Left err -> pure $ Left ("HTTP error: " <> AX.printError err)
Right json -> case decodeJson json of
Left e -> pure $ Left ("Decode error: " <> e)
Right verses -> pure $ Right verses
