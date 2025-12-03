module App.UrlState
  ( ItemSeed
  , loadSeeds
  , itemsToSeeds
  , storeSeeds
  ) where

import Prelude

import Effect (Effect)

import App.State (Item(..))
import Domain.Note.Types (Note)
import Domain.Pericope.Types (Pericope)

type ItemSeed =
  { kind :: String
  , address :: String
  , source :: String
  , content :: String
  }

itemsToSeeds :: Array Item -> Array ItemSeed
itemsToSeeds ps = ps <#> case _ of
  PericopeItem p -> pericopeSeed p
  NoteItem n -> noteSeed n
  
  where
  pericopeSeed :: Pericope -> ItemSeed
  pericopeSeed p =
    { kind: "pericope"
    , address: p.address
    , source: p.source
    , content: ""
    }

  noteSeed :: Note -> ItemSeed
  noteSeed n =
    { kind: "note"
    , address: ""
    , source: ""
    , content: n.content
    }

foreign import loadSeeds :: Effect (Array ItemSeed)

foreign import storeSeeds :: Array ItemSeed -> Effect Unit
