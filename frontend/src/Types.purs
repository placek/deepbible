module Types where

import Prelude

import Data.Argonaut (Json)
import Data.Enum (class Enum)
import Data.Maybe (Maybe)
import Data.Newtype (class Newtype)
import Data.Set as Set
import Data.Show.Generic (genericShow)
import Effect (Effect)
import Effect.Aff (Aff)
import Halogen as H
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Web.UIEvent.KeyboardEvent (KeyboardEvent)

-- A verse as returned by /rpc/verses_by_address
newtype Verse = Verse
{ book_number :: Int
, chapter :: Int
, verse :: Int
, verse_id :: String
, language :: String
, source :: String
, address :: String
, text :: String
}

derive instance newtypeVerse :: Newtype Verse _

instance showVerse :: Show Verse where
show = genericShow

-- One pericope = didascalia (address + source) + list of verses
newtype PericopeId = PericopeId Int

derive instance newtypePericopeId :: Newtype PericopeId _

type Pericope =
{ id :: PericopeId
, address :: String
, source :: String
, verses :: Array Verse
, selected :: Set.Set String -- verse_id selected
, editingAddress :: Boolean
, editingSource :: Boolean
}

-- App state = list of pericopes in order + dnd drag state
type AppState =
{ pericopes :: Array Pericope
, dragging :: Maybe PericopeId
, droppingOver :: Maybe PericopeId
, nextId :: Int
}
