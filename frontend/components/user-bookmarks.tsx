"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Bookmark, Trash2 } from "lucide-react"
import { Skeleton } from "@/components/ui/skeleton"
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog"
import { fetchBookmarks, deleteBookmark } from "@/lib/user-data"
import { useToast } from "@/hooks/use-toast"

export default function UserBookmarks({ onSelectAddress }) {
  const { toast } = useToast()
  const [bookmarks, setBookmarks] = useState([])
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    async function loadBookmarks() {
      setIsLoading(true)
      try {
        const data = await fetchBookmarks()
        setBookmarks(data)
      } catch (error) {
        toast({
          title: "Error loading bookmarks",
          description: "Could not load your bookmarks. Please try again.",
          variant: "destructive",
        })
      } finally {
        setIsLoading(false)
      }
    }

    loadBookmarks()
  }, [toast])

  const handleDeleteBookmark = async (id) => {
    try {
      await deleteBookmark(id)
      setBookmarks(bookmarks.filter((bookmark) => bookmark.id !== id))
      toast({
        description: "Bookmark deleted successfully.",
      })
    } catch (error) {
      toast({
        title: "Error deleting bookmark",
        description: "Could not delete bookmark. Please try again.",
        variant: "destructive",
      })
    }
  }

  if (isLoading) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>Your Bookmarks</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <Skeleton className="h-20 w-full" />
            <Skeleton className="h-20 w-full" />
            <Skeleton className="h-20 w-full" />
          </div>
        </CardContent>
      </Card>
    )
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Your Bookmarks</CardTitle>
      </CardHeader>
      <CardContent>
        {bookmarks.length > 0 ? (
          <div className="space-y-4">
            {bookmarks.map((bookmark) => (
              <div key={bookmark.id} className="border rounded-lg p-4 flex justify-between items-start">
                <div className="flex-1">
                  <div
                    className="font-semibold mb-1 cursor-pointer hover:underline"
                    onClick={() => onSelectAddress(bookmark.address)}
                  >
                    {bookmark.address}
                  </div>
                  <div className="text-sm line-clamp-2">{bookmark.verses[0]?.text || ""}</div>
                  {bookmark.note && (
                    <div className="mt-2 text-sm text-muted-foreground">
                      <span className="font-medium">Note:</span> {bookmark.note}
                    </div>
                  )}
                </div>

                <AlertDialog>
                  <AlertDialogTrigger asChild>
                    <Button variant="ghost" size="icon">
                      <Trash2 className="h-4 w-4" />
                    </Button>
                  </AlertDialogTrigger>
                  <AlertDialogContent>
                    <AlertDialogHeader>
                      <AlertDialogTitle>Delete Bookmark</AlertDialogTitle>
                      <AlertDialogDescription>
                        Are you sure you want to delete this bookmark? This action cannot be undone.
                      </AlertDialogDescription>
                    </AlertDialogHeader>
                    <AlertDialogFooter>
                      <AlertDialogCancel>Cancel</AlertDialogCancel>
                      <AlertDialogAction onClick={() => handleDeleteBookmark(bookmark.id)}>Delete</AlertDialogAction>
                    </AlertDialogFooter>
                  </AlertDialogContent>
                </AlertDialog>
              </div>
            ))}
          </div>
        ) : (
          <div className="text-center py-8 text-muted-foreground">
            <Bookmark className="h-12 w-12 mx-auto mb-4 opacity-20" />
            <p>You haven&apos;t saved any bookmarks yet.</p>
            <p className="text-sm">Browse verses and click the bookmark button to save them here.</p>
          </div>
        )}
      </CardContent>
    </Card>
  )
}

