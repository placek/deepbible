import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Skeleton } from "@/components/ui/skeleton"

export default function CompareView({ address, verses, isLoading }) {
  if (isLoading) {
    return (
      <Card>
        <CardHeader>
          <Skeleton className="h-6 w-3/4" />
        </CardHeader>
        <CardContent className="space-y-4">
          <Skeleton className="h-6 w-full" />
          <Skeleton className="h-6 w-full" />
          <Skeleton className="h-6 w-5/6" />
        </CardContent>
      </Card>
    )
  }

  if (!verses || verses.length === 0) {
    return (
      <Card>
        <CardContent className="py-10 text-center text-muted-foreground">
          No verses found for the address: {address}
        </CardContent>
      </Card>
    )
  }

  // Group verses by source
  const sourceGroups = {}
  verses.forEach((verse) => {
    if (!sourceGroups[verse.source]) {
      sourceGroups[verse.source] = []
    }
    sourceGroups[verse.source].push(verse)
  })

  const sources = Object.keys(sourceGroups)

  return (
    <Card>
      <CardHeader>
        <CardTitle>Compare Translations: {address}</CardTitle>
      </CardHeader>
      <CardContent>
        {sources.length > 1 ? (
          <Tabs defaultValue={sources[0]}>
            <TabsList className="grid" style={{ gridTemplateColumns: `repeat(${Math.min(sources.length, 4)}, 1fr)` }}>
              {sources.map((source) => (
                <TabsTrigger key={source} value={source}>
                  {source}
                </TabsTrigger>
              ))}
            </TabsList>

            <div className="mt-6 grid grid-cols-1 md:grid-cols-2 gap-6">
              {sources.map((source) => (
                <TabsContent key={source} value={source} className="mt-0">
                  <div className="border rounded-lg p-4">
                    <div className="font-semibold mb-3">{source}</div>
                    <div className="space-y-3">
                      {sourceGroups[source].map((verse, index) => (
                        <div key={index}>
                          {sourceGroups[source].length > 1 && (
                            <div className="text-sm font-medium text-muted-foreground mb-1">
                              Verse {verse.verseNumber}
                            </div>
                          )}
                          <div>{verse.text}</div>
                        </div>
                      ))}
                    </div>
                  </div>
                </TabsContent>
              ))}
            </div>
          </Tabs>
        ) : (
          <div className="text-center py-6 text-muted-foreground">Only one translation available for this passage.</div>
        )}

        <div className="mt-8 border rounded-lg p-6">
          <h3 className="font-semibold mb-4">Side-by-Side Comparison</h3>
          <div className="space-y-6">
            {/* If we have multiple verses, group by verse number */}
            {verses.some((v) => v.verseNumber) ? (
              // Group by verse number
              Array.from(new Set(verses.map((v) => v.verseNumber))).map((verseNum) => (
                <div key={verseNum} className="space-y-3">
                  <div className="font-medium">Verse {verseNum}</div>
                  <div className="grid gap-3">
                    {sources.map((source) => {
                      const verse = sourceGroups[source].find((v) => v.verseNumber === verseNum)
                      return verse ? (
                        <div key={source} className="grid grid-cols-[100px_1fr] gap-2">
                          <div className="font-medium text-muted-foreground">{source}:</div>
                          <div>{verse.text}</div>
                        </div>
                      ) : null
                    })}
                  </div>
                </div>
              ))
            ) : (
              // Just compare the sources
              <div className="grid gap-3">
                {sources.map((source) => (
                  <div key={source} className="grid grid-cols-[100px_1fr] gap-2">
                    <div className="font-medium text-muted-foreground">{source}:</div>
                    <div>{sourceGroups[source][0].text}</div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </CardContent>
    </Card>
  )
}

