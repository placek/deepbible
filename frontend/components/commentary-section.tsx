"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Textarea } from "@/components/ui/textarea"
import { Skeleton } from "@/components/ui/skeleton"
import { fetchCommentaries } from "@/lib/api"
import { saveUserCommentary } from "@/lib/user-data"
import { useToast } from "@/hooks/use-toast"

export default function CommentarySection({ address }) {
  const { toast } = useToast()
  const [commentaries, setCommentaries] = useState([])
  const [userCommentary, setUserCommentary] = useState("")
  const [isLoading, setIsLoading] = useState(true)
  const [activeTab, setActiveTab] = useState("published")

  useEffect(() => {
    async function loadCommentaries() {
      setIsLoading(true)
      try {
        const data = await fetchCommentaries(address)
        setCommentaries(data.published || [])
        setUserCommentary(data.user || "")
      } catch (error) {
        toast({
          title: "Error loading commentaries",
          description: "Could not load commentaries for this passage.",
          variant: "destructive",
        })
      } finally {
        setIsLoading(false)
      }
    }

    loadCommentaries()
  }, [address, toast])

  const handleSaveUserCommentary = async () => {
    try {
      await saveUserCommentary(address, userCommentary)
      toast({
        title: "Commentary saved",
        description: "Your commentary has been saved successfully.",
      })
    } catch (error) {
      toast({
        title: "Error saving commentary",
        description: "Could not save your commentary. Please try again.",
        variant: "destructive",
      })
    }
  }

  if (isLoading) {
    return (
      <Card>
        <CardHeader>
          <Skeleton className="h-8 w-3/4" />
        </CardHeader>
        <CardContent>
          <Skeleton className="h-24 w-full mb-4" />
          <Skeleton className="h-24 w-full" />
        </CardContent>
      </Card>
    )
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Commentaries for {address}</CardTitle>
      </CardHeader>
      <CardContent>
        <Tabs value={activeTab} onValueChange={setActiveTab}>
          <TabsList className="grid grid-cols-2 mb-4">
            <TabsTrigger value="published">Published Commentaries</TabsTrigger>
            <TabsTrigger value="user">Your Commentary</TabsTrigger>
          </TabsList>

          <TabsContent value="published">
            {commentaries.length > 0 ? (
              <div className="space-y-4">
                {commentaries.map((commentary, index) => (
                  <div key={index} className="border rounded-lg p-4">
                    <div className="font-semibold mb-2">{commentary.source}</div>
                    <div>{commentary.text}</div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="text-center py-8 text-muted-foreground">
                No published commentaries available for this passage.
              </div>
            )}
          </TabsContent>

          <TabsContent value="user">
            <div className="space-y-4">
              <Textarea
                placeholder="Write your own commentary for this passage..."
                value={userCommentary}
                onChange={(e) => setUserCommentary(e.target.value)}
                rows={6}
              />
              <Button onClick={handleSaveUserCommentary}>Save Commentary</Button>
            </div>
          </TabsContent>
        </Tabs>
      </CardContent>
    </Card>
  )
}

