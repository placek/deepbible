module App.UrlState
  ( ItemSeed(..)
  , decodeSeeds
  , encodeSeeds
  , getOrCreateSheetId
  , itemsToSeeds
  ) where

import Prelude

import Data.Argonaut (class DecodeJson, class EncodeJson, decodeJson, encodeJson, (.:), (.:?), (:=), (~>), jsonEmptyObject)
import Data.Argonaut.Core (Json)
import Data.Array as A
import Data.Either (Either(..))
import Data.Maybe (Maybe(..), fromMaybe)
import Effect (Effect)

import App.State (Item(..))
import Domain.Note.Types (Note)
import Domain.Pericope.Types (Pericope)

newtype ItemSeed =
  ItemSeed
    { kind :: String
    , address :: String
    , source :: String
    , content :: String
    }

newtype SheetData =
  SheetData
    { items :: Array ItemSeed
    }

instance encodeItemSeed :: EncodeJson ItemSeed where
  encodeJson (ItemSeed seed) =
    ("kind" := seed.kind)
      ~> ("address" := seed.address)
      ~> ("source" := seed.source)
      ~> ("content" := seed.content)
      ~> jsonEmptyObject

instance decodeItemSeed :: DecodeJson ItemSeed where
  decodeJson j = do
    obj <- decodeJson j
    kind <- obj .: "kind"
    address <- fromMaybe "" <$> obj .:? "address"
    source <- fromMaybe "" <$> obj .:? "source"
    content <- fromMaybe "" <$> obj .:? "content"
    pure $ ItemSeed { kind, address, source, content }

instance encodeSheetData :: EncodeJson SheetData where
  encodeJson (SheetData sheet) =
    ("items" := sheet.items) ~> jsonEmptyObject

instance decodeSheetData :: DecodeJson SheetData where
  decodeJson j = do
    obj <- decodeJson j
    items <- obj .: "items"
    pure $ SheetData { items }

itemsToSeeds :: Array Item -> Array ItemSeed
itemsToSeeds ps = ps <#> case _ of
  PericopeItem p -> pericopeSeed p
  NoteItem n -> noteSeed n
  
  where
  pericopeSeed :: Pericope -> ItemSeed
  pericopeSeed p =
    ItemSeed
      { kind: "pericope"
      , address: p.address
      , source: p.source
      , content: ""
      }

  noteSeed :: Note -> ItemSeed
  noteSeed n =
    ItemSeed
      { kind: "note"
      , address: ""
      , source: ""
      , content: n.content
      }

sanitizeSeed :: ItemSeed -> Maybe ItemSeed
sanitizeSeed (ItemSeed seed) = case seed.kind of
  "pericope" ->
    if seed.address == "" && seed.source == "" then
      Nothing
    else
      Just $ ItemSeed (seed { content = "" })
  "note" ->
    Just $ ItemSeed (seed { address = "", source = "" })
  _ ->
    Nothing

sanitizeSeeds :: Array ItemSeed -> Array ItemSeed
sanitizeSeeds = A.mapMaybe sanitizeSeed

decodeSeeds :: Json -> Array ItemSeed
decodeSeeds json = case decodeJson json of
  Right (SheetData { items }) -> sanitizeSeeds items
  Left _ -> case (decodeJson json :: Either _ (Array ItemSeed)) of
    Right items -> sanitizeSeeds items
    Left _ -> []

encodeSeeds :: Array ItemSeed -> Json
encodeSeeds seeds = encodeJson (SheetData { items: sanitizeSeeds seeds })

foreign import getOrCreateSheetId :: Effect String
