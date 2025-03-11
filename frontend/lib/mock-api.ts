// This file provides mock data for development and testing
// Use this when the actual API is not available or for development

// Mock verses data
export const mockVerses = {
  "John 3:16": [
    {
      source: "NIV",
      verseNumber: 16,
      text: "For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.",
    },
    {
      source: "KJV",
      verseNumber: 16,
      text: "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.",
    },
    {
      source: "ESV",
      verseNumber: 16,
      text: "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life.",
    },
  ],
  "Psalm 23:1-3": [
    {
      source: "NIV",
      verseNumber: 1,
      text: "The LORD is my shepherd, I lack nothing.",
    },
    {
      source: "NIV",
      verseNumber: 2,
      text: "He makes me lie down in green pastures, he leads me beside quiet waters,",
    },
    {
      source: "NIV",
      verseNumber: 3,
      text: "he refreshes my soul. He guides me along the right paths for his name's sake.",
    },
    {
      source: "KJV",
      verseNumber: 1,
      text: "The LORD is my shepherd; I shall not want.",
    },
    {
      source: "KJV",
      verseNumber: 2,
      text: "He maketh me to lie down in green pastures: he leadeth me beside the still waters.",
    },
    {
      source: "KJV",
      verseNumber: 3,
      text: "He restoreth my soul: he leadeth me in the paths of righteousness for his name's sake.",
    },
  ],
  "Romans 8:28": [
    {
      source: "NIV",
      verseNumber: 28,
      text: "And we know that in all things God works for the good of those who love him, who have been called according to his purpose.",
    },
    {
      source: "ESV",
      verseNumber: 28,
      text: "And we know that for those who love God all things work together for good, for those who are called according to his purpose.",
    },
  ],
}

// Mock commentaries data
export const mockCommentaries = {
  "John 3:16": {
    published: [
      {
        source: "Matthew Henry's Commentary",
        text: "This is the most famous verse in the Bible. It has been called 'the Bible in miniature' because it presents the entire gospel message in one verse.",
      },
      {
        source: "John MacArthur Study Bible",
        text: "This verse contains the most essential gospel truth in all the Scriptures. The love of God is the reason for the incarnation and atonement.",
      },
    ],
    user: "My personal notes on this verse...",
  },
  "Psalm 23:1-3": {
    published: [
      {
        source: "Spurgeon's Treasury of David",
        text: "This is the pearl of psalms whose soft and pure radiance delights every eye. It is the nightingale of the psalms, singing sweetest in the night.",
      },
    ],
    user: "",
  },
  "Romans 8:28": {
    published: [
      {
        source: "John Calvin's Commentary",
        text: "This is a remarkable passage, which teaches us that the Lord by his providence tempers all things for the good of the faithful.",
      },
    ],
    user: "",
  },
}

// Mock navigation data
export const mockNavigation = {
  "John 3:16": {
    previousVerse: "John 3:15",
    nextVerse: "John 3:17",
    previousChapter: "John 2",
    nextChapter: "John 4",
    previousBook: "Luke",
    nextBook: "Acts",
  },
  "Psalm 23:1-3": {
    previousVerse: "Psalm 22:31",
    nextVerse: "Psalm 23:4",
    previousChapter: "Psalm 22",
    nextChapter: "Psalm 24",
    previousBook: "Psalm 22",
    nextBook: "Psalm 24",
  },
  "Romans 8:28": {
    previousVerse: "Romans 8:27",
    nextVerse: "Romans 8:29",
    previousChapter: "Romans 7",
    nextChapter: "Romans 9",
    previousBook: "Acts",
    nextBook: "1 Corinthians",
  },
}

// Mock search results
export const mockSearchResults = [
  {
    address: "John 3:16",
    text: "For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.",
    commentaryText: "This is the most famous verse in the Bible. It has been called 'the Bible in miniature'.",
  },
  {
    address: "Romans 5:8",
    text: "But God demonstrates his own love for us in this: While we were still sinners, Christ died for us.",
    commentaryText: null,
  },
  {
    address: "1 John 4:9",
    text: "This is how God showed his love among us: He sent his one and only Son into the world that we might live through him.",
    commentaryText: "John echoes the theme from his Gospel about God's love.",
  },
]

