module App.UrlState
  ( PericopeSeed
  , loadSeeds
  , pericopesToSeeds
  , storeSeeds
  ) where

import Prelude

import Effect (Effect)

import Domain.Pericope.Types (Pericope)

type PericopeSeed =
  { address :: String
  , source :: String
  }

pericopesToSeeds :: Array Pericope -> Array PericopeSeed
pericopesToSeeds ps =
  (\p -> { address: p.address, source: p.source }) <$> ps

foreign import loadSeeds :: Effect (Array PericopeSeed)

foreign import storeSeeds :: Array PericopeSeed -> Effect Unit
