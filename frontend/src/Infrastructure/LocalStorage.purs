module Infrastructure.LocalStorage
  ( SavedSheetEntry
  , saveSheetToLocal
  , loadSheetList
  , deleteSheetFromLocal
  , navigateToSheet
  ) where

import Prelude

import Data.Argonaut.Core (Json)
import Effect (Effect)

type SavedSheetEntry =
  { sheetId :: String
  , title :: String
  , savedAt :: String
  }

foreign import saveSheetToLocal :: String -> Json -> Effect Unit
foreign import loadSheetList :: Effect (Array SavedSheetEntry)
foreign import deleteSheetFromLocal :: String -> Effect Unit
foreign import navigateToSheet :: String -> Effect Unit
