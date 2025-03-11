"use client"

import { Card, CardContent, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Bookmark, Share2 } from "lucide-react"
import { Skeleton } from "@/components/ui/skeleton"
import { saveBookmark } from "@/lib/user-data"
import { useToast } from "@/hooks/use-toast"

export default function VerseDisplay({ address, verses, isLoading }) {
  const { toast } = useToast()

  const handleBookmark = async () => {
    try {
      await saveBookmark({
        address,
        verses: verses.slice(0, 1), // Just bookmark the first verse for simplicity
      })

      toast({
        title: "Bookmark saved",
        description: `${address} has been saved to your bookmarks.`,
      })
    } catch (error) {
      toast({
        title: "Error saving bookmark",
        description: "Could not save bookmark. Please try again.",
        variant: "destructive",
      })
    }
  }

  const handleShare = () => {
    if (navigator.share) {
      navigator
        .share({
          title: address,
          text: `${verses[0]?.text || ""} - ${address}`,
          url: window.location.href,
        })
        .catch((error) => {
          toast({
            title: "Error sharing",
            description: "Could not share these verses.",
            variant: "destructive",
          })
        })
    } else {
      // Fallback for browsers that don't support navigator.share
      const textToShare = verses.map((v) => `${v.text} (${v.source})`).join("\n\n")
      navigator.clipboard.writeText(`${address}\n\n${textToShare}\n${window.location.href}`).then(() => {
        toast({
          description: "Verses copied to clipboard",
        })
      })
    }
  }

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
        <CardFooter className="flex justify-between">
          <Skeleton className="h-10 w-24" />
          <Skeleton className="h-10 w-24" />
        </CardFooter>
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
  const defaultSource = verses[0]?.source || "Unknown"
  const versesFromDefaultSource = verses.filter((v) => v.source === defaultSource)

  return (
    <Card>
      <CardHeader>
        <CardTitle>{address}</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        {versesFromDefaultSource.map((verse, index) => (
          <div key={index} className="pb-2">
            {versesFromDefaultSource.length > 1 && (
              <div className="text-sm font-medium text-muted-foreground mb-1">Verse {verse.verseNumber}</div>
            )}
            <div className="text-lg">{verse.text}</div>
          </div>
        ))}
        <div className="text-sm text-muted-foreground mt-2">Source: {defaultSource}</div>
      </CardContent>
      <CardFooter className="flex justify-between">
        <Button variant="outline" onClick={handleBookmark}>
          <Bookmark className="h-4 w-4 mr-2" />
          Bookmark
        </Button>
        <Button variant="outline" onClick={handleShare}>
          <Share2 className="h-4 w-4 mr-2" />
          Share
        </Button>
      </CardFooter>
    </Card>
  )
}

