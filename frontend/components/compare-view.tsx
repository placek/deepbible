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
          Nie znaleziono wersetów dla adresu: {address}
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
        <CardTitle>Porównanie tłumaczeń: {address}</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="mt-8 border rounded-lg p-6">
          <div className="space-y-6">
            {/* If we have multiple verses, group by verse number */}
            {verses.some((v) => v.verse) ? (
              // Group by verse number
              Array.from(new Set(verses.map((v) => v.verse))).map((verseNum) => (
                <div key={verseNum} className="space-y-3">
                  <div className="font-medium">Werset {verseNum}</div>
                  <div className="grid gap-3">
                    {sources.map((source) => {
                      const verse = sourceGroups[source].find((v) => v.verse === verseNum)
                      return verse ? (
                        <div key={source} className="grid grid-cols-[100px_1fr] gap-2">
                          <div className="font-medium text-muted-foreground">{source}:</div>
                           <div dangerouslySetInnerHTML={{ __html: verse.text }} />
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

