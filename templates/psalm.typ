// DeepBible psalm template
// Renders psalms with one verse per line.
// The first verse of each psalm (inscription) is rendered in italic.
//
// Usage:
//   make render-typst ADDRESS="Ψλ" SOURCE="LXXAJ+" TEMPLATE="templates/psalm.typ"
//   make render-typst ADDRESS="Ψλ 1" SOURCE="LXXAJ+" TEMPLATE="templates/psalm.typ"

#let data = json(sys.inputs.data)

// --- address formatting helper ---
#let fmt-range(book, first, last) = {
  if first.chapter == last.chapter {
    if first.verse == last.verse {
      book + " " + str(first.chapter) + "," + str(first.verse)
    } else {
      book + " " + str(first.chapter) + "," + str(first.verse) + sym.dash.en + str(last.verse)
    }
  } else {
    book + " " + str(first.chapter) + "," + str(first.verse) + sym.space.thin + sym.dash.en + sym.space.thin + str(last.chapter) + "," + str(last.verse)
  }
}

// --- page setup ---
#set page(
  paper: "a5",
  margin: (top: 2.5cm, bottom: 2cm, left: 2cm, right: 2cm),
  header: context {
    let here = counter(page).get().first()
    if here > 1 {
      let markers = query(<verse-marker>).filter(m =>
        counter(page).at(m.location()).first() == here
      )
      set text(size: 8pt, fill: rgb("#dc322f"))
      if markers.len() > 0 {
        let first = markers.first().value
        let last = markers.last().value
        align(center, fmt-range(data.book, first, last))
      } else {
        align(center, data.book_name + sym.space.thin + sym.dash.en + sym.space.thin + data.source)
      }
    }
  },
  footer: context {
    set text(size: 8pt, fill: rgb("#93a1a1"))
    align(center, counter(page).display())
  },
)

// --- solarized palette ---
#let color-text     = rgb("#586e75")
#let color-muted    = rgb("#93a1a1")
#let color-address  = rgb("#dc322f")
#let color-jesus    = rgb("#cb4b16")
#let color-footnote = rgb("#6c71c4")
#let color-bg       = rgb("#fdf6e3")

// --- fonts ---
#set text(font: "New Athena Unicode", size: 11pt, fill: color-text, lang: "el")
#set par(justify: false, leading: 0.7em)

// --- strip HTML tags from verse text ---
#let strip-tags(src) = {
  let s = src
  s = s.replace(regex("<[a-zA-Z]+\s*/>"), "")
  s = s.replace(regex("<f>[^<]*</f>"), "")
  s = s.replace(regex("<e>[^<]*</e>"), "")
  s = s.replace(regex("<n>[^<]*</n>"), "")
  s = s.replace(regex("<m>[^<]*</m>"), "")
  s = s.replace(regex("<S>[^<]*</S>"), "")
  s = s.replace(regex("<[^>]+>"), "")
  s = s.replace(regex("\\s+"), " ")
  s.trim()
}

// --- title page ---
#align(center + horizon)[
  #text(size: 24pt, weight: "bold", fill: color-text)[#data.book_name]
  #v(0.5em)
  #text(size: 12pt, fill: color-muted)[#data.source]
  #if data.address != data.book [
    #v(0.3em)
    #text(size: 10pt, fill: color-address)[#data.address]
  ]
]

#pagebreak()

// --- render psalms ---
#let chapter-keys = data.chapters.keys().sorted(key: k => int(k))

#for ch in chapter-keys {
  let verses = data.chapters.at(ch)

  // psalm number
  v(1.5em)
  align(center)[
    #text(size: 14pt, weight: "bold", fill: color-address)[#ch]
  ]
  v(0.5em)

  // one verse per line; first verse (inscription) in italic
  for v in verses {
    let clean = strip-tags(v.text)
    if clean.len() > 0 {
      [#metadata((chapter: int(ch), verse: v.verse)) <verse-marker>]
      if v.verse == 1 [
        #text(size: 7pt, fill: color-address, baseline: -0.3em)[#str(v.verse)]
        #h(1pt)
        #emph[#clean] \
      ] else [
        #text(size: 7pt, fill: color-address, baseline: -0.3em)[#str(v.verse)]
        #h(1pt)
        #clean \
      ]
    }
  }
}
