#let (..data) = csv("j.csv")
#let schapter = counter("schapter")
#let sverse = counter("sverse")
#schapter.update(1)
#sverse.update(1)

#set text(size: 8pt)
#set page(header: [ #context(text(font: "Iosevka NFM")[
  #if calc.odd(int(counter(page).display())) [
    #counter(page).display() #h(1fr) J #schapter.display(),#sverse.display()
  ] else [
    J #schapter.display(),#sverse.display() #h(1fr) #counter(page).display()
  ]
])], paper: "a6")

#par(justify: true)[
  #for (chapter, verse, datum) in data [
    #let textus = datum.replace(regex("<f>([^<]*)</f>"), it => it.captures.at(0)).replace(regex("<[^>]*>"), "")
    #schapter.update(int(chapter))
    #sverse.update(int(verse))
    #if chapter == "1" and verse == "1" [
      #strong(textus)
    ] else if verse == "1" [
      #linebreak(justify: true)
      #text(font: "Iosevka NFM", fill: red, chapter) #textus
    ] else [
      #super(text(font: "Iosevka NFM", fill: red, verse))#textus
    ]
  ]
]
