// This file contains functions to interact with the backend API

// Add these imports at the top of the file
import { mockVerses, mockCommentaries, mockNavigation, mockSearchResults } from "./mock-api"

// Fetch verses based on address
export async function fetchVerses(address: string) {
  try {
    // First try to fetch from the API
    try {
      const response = await fetch(`/api/verses?address=${encodeURIComponent(address)}`, {
        headers: {
          Accept: "application/json",
        },
      })

      if (response.ok) {
        const contentType = response.headers.get("content-type")
        if (contentType && contentType.includes("application/json")) {
          return await response.json()
        }
      }

      // If we get here, there was an issue with the API response
      throw new Error("API response issue")
    } catch (apiError) {
      console.warn("API fetch failed, using mock data:", apiError)

      // Fall back to mock data
      if (mockVerses[address]) {
        return mockVerses[address]
      } else {
        // Try to find a partial match in mock data
        const keys = Object.keys(mockVerses)
        for (const key of keys) {
          if (address.includes(key) || key.includes(address)) {
            return mockVerses[key]
          }
        }

        // If no match found, return the first mock data
        return mockVerses["John 3:16"]
      }
    }
  } catch (error) {
    console.error("Error in fetchVerses:", error)
    // Return empty array instead of throwing to prevent app crashes
    return []
  }
}

// Fetch commentaries for a specific verse or passage
export async function fetchCommentaries(address: string) {
  try {
    // First try to fetch from the API
    try {
      const response = await fetch(`/api/commentaries?address=${encodeURIComponent(address)}`, {
        headers: {
          Accept: "application/json",
        },
      })

      if (response.ok) {
        const contentType = response.headers.get("content-type")
        if (contentType && contentType.includes("application/json")) {
          return await response.json()
        }
      }

      // If we get here, there was an issue with the API response
      throw new Error("API response issue")
    } catch (apiError) {
      console.warn("API fetch failed, using mock data:", apiError)

      // Fall back to mock data
      if (mockCommentaries[address]) {
        return mockCommentaries[address]
      } else {
        // Try to find a partial match in mock data
        const keys = Object.keys(mockCommentaries)
        for (const key of keys) {
          if (address.includes(key) || key.includes(address)) {
            return mockCommentaries[key]
          }
        }

        // If no match found, return empty data
        return { published: [], user: "" }
      }
    }
  } catch (error) {
    console.error("Error in fetchCommentaries:", error)
    // Return empty data instead of throwing to prevent app crashes
    return { published: [], user: "" }
  }
}

// Fetch navigation information (previous/next verse, chapter, book)
export async function fetchNavigation(address: string) {
  try {
    // First try to fetch from the API
    try {
      const response = await fetch(`/api/navigation?address=${encodeURIComponent(address)}`, {
        headers: {
          Accept: "application/json",
        },
      })

      if (response.ok) {
        const contentType = response.headers.get("content-type")
        if (contentType && contentType.includes("application/json")) {
          return await response.json()
        }
      }

      // If we get here, there was an issue with the API response
      throw new Error("API response issue")
    } catch (apiError) {
      console.warn("API fetch failed, using mock data:", apiError)

      // Fall back to mock data
      if (mockNavigation[address]) {
        return mockNavigation[address]
      } else {
        // Try to find a partial match in mock data
        const keys = Object.keys(mockNavigation)
        for (const key of keys) {
          if (address.includes(key) || key.includes(address)) {
            return mockNavigation[key]
          }
        }

        // If no match found, return the first mock data
        return mockNavigation["John 3:16"]
      }
    }
  } catch (error) {
    console.error("Error in fetchNavigation:", error)
    // Return empty navigation data instead of throwing to prevent app crashes
    return {
      previousVerse: "",
      nextVerse: "",
      previousChapter: "",
      nextChapter: "",
      previousBook: "",
      nextBook: "",
    }
  }
}

// Search the Bible (this would need to be implemented on the backend)
export async function searchBible(query: string, scope: string) {
  try {
    // First try to fetch from the API
    try {
      const response = await fetch(`/api/search?query=${encodeURIComponent(query)}&scope=${scope}`, {
        headers: {
          Accept: "application/json",
        },
      })

      if (response.ok) {
        const contentType = response.headers.get("content-type")
        if (contentType && contentType.includes("application/json")) {
          return await response.json()
        }
      }

      // If we get here, there was an issue with the API response
      throw new Error("API response issue")
    } catch (apiError) {
      console.warn("API fetch failed, using mock data:", apiError)

      // Filter mock results based on query
      if (query) {
        const lowerQuery = query.toLowerCase()
        return mockSearchResults.filter(
          (result) =>
            result.text.toLowerCase().includes(lowerQuery) ||
            (result.commentaryText && result.commentaryText.toLowerCase().includes(lowerQuery)),
        )
      }

      return mockSearchResults
    }
  } catch (error) {
    console.error("Error in searchBible:", error)
    // Return empty array instead of throwing to prevent app crashes
    return []
  }
}

