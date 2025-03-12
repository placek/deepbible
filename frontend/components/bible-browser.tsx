"use client"

import { useState, useEffect } from "react"
import { useSearchParams, useRouter } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { ChevronLeft, ChevronRight, Search, Bookmark, BookOpen, MessageSquare, Layers } from "lucide-react"
import VerseDisplay from "./verse-display"
import CommentarySection from "./commentary-section"
import SearchPanel from "./search-panel"
import UserBookmarks from "./user-bookmarks"
import CompareView from "./compare-view"
import { fetchVerses, fetchNavigation } from "@/lib/api"
import { useToast } from "@/hooks/use-toast"

export default function BibleBrowser() {
  const searchParams = useSearchParams()
  const router = useRouter()
  const { toast } = useToast()

  // Get initial address from URL or default
  const initialAddress = searchParams.get("address") || "J 1,1"

  const [address, setAddress] = useState(initialAddress)
  const [verses, setVerses] = useState([])
  const [activeTab, setActiveTab] = useState("verses")
  const [isLoading, setIsLoading] = useState(true)

  // Load verses based on current address
  useEffect(() => {
    async function loadVerses() {
      setIsLoading(true)
      try {
        // First try to fetch the verses
        const data = await fetchVerses(address)
        setVerses(data)

        // Update URL with current address
        router.push(`?address=${encodeURIComponent(address)}`, { scroll: false })
      } catch (error) {
        console.error("Verse fetch error:", error)
        setVerses([])
        toast({
          title: "Error loading verses",
          description: "Could not load the requested verses. Please check the address format and try again.",
          variant: "destructive",
        })
      } finally {
        setIsLoading(false)
      }
    }

    loadVerses()
  }, [address, router, toast])

  // Handle address input
  const handleAddressSubmit = (e) => {
    e.preventDefault()
    // The address format is more flexible now, so we don't need to validate as strictly
    setAddress(address.trim())
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col md:flex-row gap-4">
        <form onSubmit={handleAddressSubmit} className="flex-1">
          <div className="flex gap-2">
            <Input
              value={address}
              onChange={(e) => setAddress(e.target.value)}
              placeholder="np. J 3,16 lub Rz 8,28-39"
              className="flex-1"
            />
            <Button type="submit">Go</Button>
          </div>
        </form>
      </div>

      <Tabs value={activeTab} onValueChange={setActiveTab}>
        <TabsList className="grid grid-cols-5">
          <TabsTrigger value="verses">
            <BookOpen className="h-4 w-4 mr-2" />
            Perykopa
          </TabsTrigger>
          <TabsTrigger value="compare">
            <Layers className="h-4 w-4 mr-2" />
            Porównanie tłumaczeń
          </TabsTrigger>
          <TabsTrigger value="commentary">
            <MessageSquare className="h-4 w-4 mr-2" />
            Komentarze
          </TabsTrigger>
          <TabsTrigger value="search">
            <Search className="h-4 w-4 mr-2" />
            Wyszukiwanie
          </TabsTrigger>
          <TabsTrigger value="bookmarks">
            <Bookmark className="h-4 w-4 mr-2" />
            Zakładki
          </TabsTrigger>
        </TabsList>

        <TabsContent value="verses" className="mt-4">
          <VerseDisplay address={address} verses={verses} isLoading={isLoading} />
        </TabsContent>

        <TabsContent value="compare" className="mt-4">
          <CompareView address={address} verses={verses} isLoading={isLoading} />
        </TabsContent>

        <TabsContent value="commentary" className="mt-4">
          <CommentarySection address={address} />
        </TabsContent>

        <TabsContent value="search" className="mt-4">
          <SearchPanel
            onSelectAddress={(newAddress) => {
              setAddress(newAddress)
              setActiveTab("verses")
            }}
          />
        </TabsContent>

        <TabsContent value="bookmarks" className="mt-4">
          <UserBookmarks
            onSelectAddress={(newAddress) => {
              setAddress(newAddress)
              setActiveTab("verses")
            }}
          />
        </TabsContent>
      </Tabs>
    </div>
  )
}
