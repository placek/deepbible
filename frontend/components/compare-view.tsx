"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { fetchVerses } from "@/lib/api"
import { useToast } from "@/hooks/use-toast"

export default function CompareView({ address }) {
  const { toast } = useToast()
  const [verses, setVerses] = useState([])
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    async function loadVerses() {
      setIsLoading(true)
      try {
        const data = await fetchVerses(address)
        setVerses(data)
      } catch (error) {
        console.error("Verse fetch error:", error)
        setVerses([])
        toast({
          title: "Błąd ładowania wersetów",
          description: "Nie udało się załadować wersetów dla podanego adresu. Spróbuj ponownie.",
          variant: "destructive",
        })
      } finally {
        setIsLoading(false)
      }
    }

    loadVerses()
  }, [address, toast])

  if (isLoading) {
    return (
      <Card>
        <CardContent className="py-10 text-center text-muted-foreground">
          Ładowanie wersetów dla podanego adresu: {address}
        </CardContent>
      </Card>
    )
  }

  if (!verses || verses.length === 0) {
    return (
      <Card>
        <CardContent className="py-10 text-center text-muted-foreground">
          Brak wersetów dla podanego adresu: {address}
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
        <div className="space-y-6">
          {Array.from(new Set(verses.map((v) => v.address))).map((verseAddr) => (
            <div key={verseAddr} className="border rounded-lg p-4">
              <div className="font-semibold mb-2">{verseAddr}</div>
              <div className="grid gap-3">
                {sources.map((source) => {
                  const verse = sourceGroups[source].find((v) => v.address === verseAddr)
                  return verse ? (
                    <div key={source} className="grid grid-cols-[100px_1fr] gap-2">
                      <div className="font-medium text-muted-foreground">{source}:</div>
                       <div dangerouslySetInnerHTML={{ __html: verse.text }} />
                    </div>
                  ) : null
                })}
              </div>
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  )
}
