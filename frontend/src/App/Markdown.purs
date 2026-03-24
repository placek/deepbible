module App.Markdown (renderSheetMarkdown, downloadMarkdownFile) where

import Prelude

import Data.Array as A
import Data.String (joinWith)
import Effect (Effect)

import App.State (Item(..))
import Domain.Bible.Types (Verse(..))
import Domain.Pericope.Types (Pericope)

foreign import htmlToText :: String -> String
foreign import downloadMarkdownFile :: String -> String -> Effect Unit

renderSheetMarkdown :: Array Item -> String
renderSheetMarkdown items =
  joinWith "\n\n" (renderItem <$> items)

renderItem :: Item -> String
renderItem = case _ of
  NoteItem note -> note.content
  PericopeItem pericope -> renderPericope pericope

renderPericope :: Pericope -> String
renderPericope pericope =
  let
    header =
      blockquoteLine
        ("Source: " <> pericope.source <> " | Address: " <> pericope.address)
    verseLines = pericope.verses <#> renderVerseLine
  in
    joinWith "\n" (A.cons header verseLines)

renderVerseLine :: Verse -> String
renderVerseLine (Verse verse) =
  let
    cleanText = htmlToText verse.text
    line =
      if cleanText == "" then
        show verse.verse
      else
        show verse.verse <> " " <> cleanText
  in
    blockquoteLine line

blockquoteLine :: String -> String
blockquoteLine content = "> " <> content
