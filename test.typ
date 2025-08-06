#let (_, ..data) = csv("data/pl-PAU_la-NVUL.csv")

#let schapter = counter("schapter")
#let sverse = counter("sverse")
#sverse.update(1)
#schapter.update(1)
#let group(data) = data.fold(
  (:),
  (dict, row) => {
    let (key, verse, l, r) = row
    let (left, right) = dict.at(key, default: ((:), (:)))
    left.insert(verse, l)
    right.insert(verse, r)
    dict.insert(key, (left, right))
    dict
  }
)

// #set text(font: "Pfeffer Simpelgotisch")
#set text(size: 8pt)
#set page(header: [Ps #context schapter.display(),#context sverse.display() #h(1fr) #context counter(page).display()], "a6")

#heading(text(fill: red)[Psalmy], level: 1)

#for (psalm, textus) in group(data) [
  #schapter.update(int(psalm))
  #heading(text(fill: red)[Psalm #psalm], level: 2)
  #grid(
    columns: (1fr, 1fr),
    gutter: 1em,
    ..textus.map(it => [
      #par(justify: true)[
        #for (v, t) in it.pairs() [
          #sverse.update(int(v))
          #let te = t.replace(regex("(\p{Po})\s*"), it => it.captures.at(0) + " ")
          #if v != "1" [
            #super(text(fill: red, v))
            #t.replace(regex("([\.\?!;:,])\s*"), it => it.captures.at(0) + " ")
          ] else [
            #emph(t) \
          ]
        ]
      ]
    ])
  )
]
