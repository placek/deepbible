"use client"

import { useState } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group"
import { Label } from "@/components/ui/label"
import { Loader2 } from "lucide-react"
import { searchBible } from "@/lib/api"
import { useToast } from "@/hooks/use-toast"

export default function SearchPanel({ onSelectAddress }) {
  const { toast } = useToast()

  const [searchQuery, setSearchQuery] = useState("")
  const [searchScope, setSearchScope] = useState("all")
  const [isSearching, setIsSearching] = useState(false)
  const [searchResults, setSearchResults] = useState([])

  const handleSearch = async (e) => {
    e.preventDefault()

    if (!searchQuery.trim()) {
      toast({
        title: "Search query required",
        description: "Please enter a search term.",
        variant: "destructive",
      })
      return
    }

    setIsSearching(true)

    try {
      const results = await searchBible(searchQuery, searchScope)
      setSearchResults(results)

      if (results.length === 0) {
        toast({
          description: "No results found for your search query.",
        })
      }
    } catch (error) {
      toast({
        title: "Search error",
        description: "An error occurred while searching. Please try again.",
        variant: "destructive",
      })
    } finally {
      setIsSearching(false)
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Search the Bible</CardTitle>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSearch} className="space-y-4">
          <div className="flex flex-col md:flex-row gap-4">
            <div className="flex-1">
              <Input
                placeholder="Enter search term..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />
            </div>
          </div>

          <div>
            <div className="mb-2">Search in:</div>
            <RadioGroup value={searchScope} onValueChange={setSearchScope} className="flex flex-wrap gap-4">
              <div className="flex items-center space-x-2">
                <RadioGroupItem value="all" id="all" />
                <Label htmlFor="all">Bible & Commentaries</Label>
              </div>
              <div className="flex items-center space-x-2">
                <RadioGroupItem value="bible" id="bible" />
                <Label htmlFor="bible">Bible Only</Label>
              </div>
              <div className="flex items-center space-x-2">
                <RadioGroupItem value="commentary" id="commentary" />
                <Label htmlFor="commentary">Commentaries Only</Label>
              </div>
            </RadioGroup>
          </div>

          <Button type="submit" disabled={isSearching}>
            {isSearching ? (
              <>
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                Searching...
              </>
            ) : (
              "Search"
            )}
          </Button>
        </form>

        {searchResults.length > 0 && (
          <div className="mt-6">
            <h3 className="font-semibold mb-4">Search Results ({searchResults.length})</h3>
            <div className="space-y-4">
              {searchResults.map((result, index) => (
                <div
                  key={index}
                  className="border rounded-lg p-4 cursor-pointer hover:bg-muted transition-colors"
                  onClick={() => onSelectAddress(result.address)}
                >
                  <div className="font-semibold mb-1">{result.address}</div>
                  <div
                    dangerouslySetInnerHTML={{
                      __html: result.text.replace(new RegExp(`(${searchQuery})`, "gi"), "<mark>$1</mark>"),
                    }}
                  />
                  {result.commentaryText && (
                    <div className="mt-2 text-sm text-muted-foreground">
                      <span className="font-medium">Commentary:</span>{" "}
                      <span
                        dangerouslySetInnerHTML={{
                          __html: result.commentaryText.replace(
                            new RegExp(`(${searchQuery})`, "gi"),
                            "<mark>$1</mark>",
                          ),
                        }}
                      />
                    </div>
                  )}
                </div>
              ))}
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  )
}

