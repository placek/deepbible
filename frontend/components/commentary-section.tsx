"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { fetchCommentaries } from "@/lib/api"
import { useToast } from "@/hooks/use-toast"
import AddressedTile from "./addressed-tile"

export default function CommentarySection({ address }) {
  const { toast } = useToast()
  const [commentaries, setCommentaries] = useState([])
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    async function loadCommentaries() {
      setIsLoading(true)
      try {
        const data = await fetchCommentaries(address)
        setCommentaries(data || [])
      } catch (error) {
        toast({
          title: "Błąd ładowania komentarzy",
          description: "Nie udało się załadować komentarzy dla podanego adresu. Spróbuj ponownie.",
          variant: "destructive",
        })
      } finally {
        setIsLoading(false)
      }
    }

    loadCommentaries()
  }, [address, toast])

  if (isLoading) {
    return (
      <Card>
        <CardContent className="py-10 text-center text-muted-foreground">
          Ładowanie komentarzy dla podanego adresu: {address}
        </CardContent>
      </Card>
    )
  }

  if (!commentaries || commentaries.length === 0) {
    return (
      <Card>
        <CardContent className="py-10 text-center text-muted-foreground">
          Brak komentarzy dla podanego adresu: {address}
        </CardContent>
      </Card>
    )
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Komentarze dla adresu: {address}</CardTitle>
      </CardHeader>

      <CardContent className="space-y-4">
        {commentaries.map(commentary => (
          <AddressedTile
            source={commentary.source}
            address={commentary.address_from + (!commentary.address_to ? "" : " - " + commentary.address_to)}
            content={commentary.text} />
        ))}
      </CardContent>
    </Card>
  )
}
