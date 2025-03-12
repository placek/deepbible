import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'deepBible',
  description: 'deepBible is a Bible study app that helps you explore the Bible in depth.',
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
