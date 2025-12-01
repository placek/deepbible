module Search.Highlight where

import Data.Maybe (Maybe)
import Data.Nullable (Nullable)
import Data.Nullable as Nullable

type HighlightSegment =
  { text :: String
  , color :: Nullable String
  }

foreign import splitSearchInput :: String -> Array HighlightSegment

toMaybeColor :: HighlightSegment -> Maybe String
toMaybeColor segment = Nullable.toMaybe segment.color
