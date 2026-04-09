module App.Markdown (renderSheetMarkdown, downloadMarkdownFile) where

import Prelude

import Data.Array as A
import Data.String (joinWith)
import Effect (Effect)

import App.State (Item(..))
import Domain.Bible.Types (Verse(..))
import Domain.Pericope.Types (Pericope)

foreign import htmlToText :: String -> String
foreign import stripSmTags :: String -> String
foreign import downloadMarkdownFile :: String -> String -> Effect Unit

renderSheetMarkdown :: String -> Array Item -> String
renderSheetMarkdown title items =
  let
    titleBlock = if title == "" then [] else ["# " <> title]
    body = renderItem <$> items
  in
    joinWith "\n\n" (titleBlock <> body)

renderItem :: Item -> String
renderItem = case _ of
  NoteItem note -> stripSmTags note.content
  PericopeItem pericope -> renderPericope pericope

renderPericope :: Pericope -> String
renderPericope pericope =
  let
    header =
      "###### " <> pericope.address <> " (" <> pericope.source <> ")"
    verseLines = pericope.verses <#> renderVerseLine
  in
    joinWith "\n" (A.cons header verseLines)

renderVerseLine :: Verse -> String
renderVerseLine (Verse verse) =
  let
    cleanText = htmlToText (stripSmTags verse.text)
    verseNumber = "<sup>" <> show verse.verse <> "</sup>"
    line =
      if cleanText == "" then
        verseNumber
      else
        verseNumber <> " " <> cleanText
  in
    "- " <> line
