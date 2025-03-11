import { Suspense } from "react"
import BibleBrowser from "@/components/bible-browser"
import { Skeleton } from "@/components/ui/skeleton"

export default function Home() {
  return (
    <main className="container mx-auto py-6 px-4 md:px-6">
      <h1 className="text-3xl font-bold mb-6">Bible Verse Browser</h1>
      <Suspense fallback={<BrowserSkeleton />}>
        <BibleBrowser />
      </Suspense>
    </main>
  )
}

function BrowserSkeleton() {
  return (
    <div className="space-y-4">
      <div className="flex flex-col md:flex-row gap-4">
        <Skeleton className="h-10 w-full md:w-1/3" />
        <Skeleton className="h-10 w-full md:w-1/3" />
      </div>
      <Skeleton className="h-[300px] w-full" />
      <Skeleton className="h-[200px] w-full" />
    </div>
  )
}

