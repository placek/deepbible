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
import CompareView from "./compare-view"
import { useToast } from "@/hooks/use-toast"

export default function BibleBrowser() {
  const searchParams = useSearchParams()
  const router = useRouter()
  const { toast } = useToast()

  // Get initial address from URL or default
  const initialAddress = searchParams.get("address") || "J 1,1"

  const [address, setAddress] = useState(initialAddress)
  const [activeTab, setActiveTab] = useState("verses")
  const [isLoading, setIsLoading] = useState(true)

  const handleAddressSubmit = (e) => {
    e.preventDefault()
    setAddress(address.trim())
  }

  const handleAddress = (address) => {
    setAddress(address)
    router.push(`?address=${encodeURIComponent(address)}`, { scroll: false })
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col md:flex-row gap-4">
        <form onSubmit={handleAddressSubmit} className="flex-1">
          <div className="flex gap-2">
            <Input
              value={address}
              onChange={(e) => handleAddress(e.target.value)}
              placeholder="np. J 3,16 lub Rz 8,28-39"
              className="flex-1"
            />
            <Button type="submit">Go</Button>
          </div>
        </form>
      </div>

      <Tabs value={activeTab} onValueChange={setActiveTab}>
        <TabsList className="grid grid-cols-4">
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
        </TabsList>

        <TabsContent value="verses" className="mt-4">
          <VerseDisplay address={address} />
        </TabsContent>

        <TabsContent value="compare" className="mt-4">
          <CompareView address={address} />
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
      </Tabs>
    </div>
  )
}
