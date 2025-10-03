{ name = "deepbible-frontend"
, dependencies =
  [ "aff"
  , "affjax"
  , "argonaut-core"
  , "argonaut-codecs"
  , "arrays"
  , "console"
  , "effect"
  , "either"
  , "foldable-traversable"
  , "halogen"
  , "maybe"
  , "newtype"
  , "prelude"
  , "strings"
  , "tailrec"
  ]
, packages = ./packages.dhall
, sources =
  [ "src/**/*.purs"
  ]
}
