"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { fetchVerses } from "@/lib/api"
import { useToast } from "@/hooks/use-toast"
import AddressedTile from "./addressed-tile"

export default function VerseDisplay({ address }) {
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
  const defaultSource = "PAU"
  const versesFromDefaultSource = verses.filter((v) => v.source === defaultSource)

  return (
    <Card>
      <CardHeader>
        <CardTitle>Wersety dla adresu: {address}</CardTitle>
      </CardHeader>

      <CardContent className="space-y-4">
        {versesFromDefaultSource.map(verse => (
          <AddressedTile
            source={verse.source}
            address={verse.address}
            content={verse.text} />
        ))}
      </CardContent>
    </Card>
  )
}
