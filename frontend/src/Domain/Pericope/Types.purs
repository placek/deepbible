module Domain.Pericope.Types where

import Data.Set as Set

import Domain.Bible.Types (Address, Source, Verse, VerseId)

type PericopeId = Int

type Pericope =
  { id :: PericopeId
  , address :: Address
  , source :: Source
  , verses :: Array Verse
  , selected :: Set.Set VerseId
  }
