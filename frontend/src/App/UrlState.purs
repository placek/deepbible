module App.UrlState
  ( ItemSeed(..)
  , SheetPayload
  , decodeSheet
  , encodeSheet
  , getSearchQueryParam
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
    { title :: String
    , items :: Array ItemSeed
    }

type SheetPayload =
  { title :: String
  , items :: Array ItemSeed
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
    ("title" := sheet.title)
      ~> ("items" := sheet.items)
      ~> jsonEmptyObject

instance decodeSheetData :: DecodeJson SheetData where
  decodeJson j = do
    obj <- decodeJson j
    title <- fromMaybe "" <$> obj .:? "title"
    items <- obj .: "items"
    pure $ SheetData { title, items }

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

decodeSheet :: Json -> SheetPayload
decodeSheet json = case decodeJson json of
  Right (SheetData { title, items }) -> { title, items: sanitizeSeeds items }
  Left _ -> case (decodeJson json :: Either _ (Array ItemSeed)) of
    Right items -> { title: "", items: sanitizeSeeds items }
    Left _ -> { title: "", items: [] }

encodeSheet :: String -> Array ItemSeed -> Json
encodeSheet title seeds =
  encodeJson (SheetData { title, items: sanitizeSeeds seeds })

foreign import getOrCreateSheetId :: Effect String
foreign import getSearchQueryParam :: Effect String
