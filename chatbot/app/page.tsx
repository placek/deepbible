"use client"

import type React from "react"

import { useState, useEffect, useRef } from "react"

interface Message {
  id: string
  role: "user" | "assistant"
  content: string
}

export default function ChatBot() {
  const [messages, setMessages] = useState<Message[]>([])
  const [input, setInput] = useState("")
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [sessionId, setSessionId] = useState<string>("")
  const messagesEndRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    setSessionId(Math.random().toString(36).substring(2, 15))
  }, [])

  useEffect(() => {
    scrollToBottom()
  }, []) //Removed unnecessary dependency: [messages]

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" })
  }

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setInput(e.target.value)
    setError(null)
  }

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    if (!input.trim()) return

    const userMessage: Message = {
      id: Date.now().toString(),
      role: "user",
      content: input.trim(),
    }

    setMessages((prevMessages) => [...prevMessages, userMessage])
    setInput("")
    setIsLoading(true)
    setError(null)

    try {
      const response = await fetch("/api/chat", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: userMessage.content,
          sessionId: sessionId,
        }),
      })

      const data = await response.json()

      if (!response.ok) {
        throw new Error(data.error || "Failed to get response")
      }

      if (!data.response) {
        throw new Error("Invalid response format")
      }

      const assistantMessage: Message = {
        id: Date.now().toString(),
        role: "assistant",
        content: data.response,
      }

      setMessages((prevMessages) => [...prevMessages, assistantMessage])
    } catch (error) {
      console.error("Chat error:", error)
      setError(error instanceof Error ? error.message : "Failed to send message")

      setMessages((prevMessages) => [
        ...prevMessages,
        {
          id: Date.now().toString(),
          role: "assistant",
          content: "Sorry, I encountered an error. Please try again.",
        },
      ])
    } finally {
      setIsLoading(false)
    }
  }

  const formatMessage = (content: string) => {
    return content.split("\n").map((line, index) => (
      <span key={index}>
        {line}
        <br />
      </span>
    ))
  }

  return (
    <div className="container mx-auto max-w-2xl p-4">
      <h1 className="text-2xl font-bold mb-4">deepBible</h1>
      <div className="bg-gray-100 p-4 rounded-lg h-96 overflow-y-auto mb-4">
        {messages.map((message) => (
          <div key={message.id} className={`mb-2 ${message.role === "user" ? "text-right" : "text-left"}`}>
            <span
              className={`inline-block p-2 rounded-lg ${
                message.role === "user" ? "bg-blue-500 text-white" : "bg-gray-300"
              }`}
            >
              {formatMessage(message.content)}
            </span>
          </div>
        ))}
        {isLoading && (
          <div className="text-left">
            <span className="inline-block p-2 rounded-lg bg-gray-300">Thinking...</span>
          </div>
        )}
        <div ref={messagesEndRef} /> {/* This empty div is used as a scroll target */}
      </div>
      {error && <div className="mb-4 p-2 bg-red-100 border border-red-400 text-red-700 rounded">{error}</div>}
      <form onSubmit={handleSubmit} className="flex">
        <input
          type="text"
          value={input}
          onChange={handleInputChange}
          placeholder="Type your message..."
          className="flex-grow border border-gray-300 rounded-l-lg px-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
          disabled={isLoading}
        />
        <button
          type="submit"
          className="bg-blue-500 text-white px-4 py-2 rounded-r-lg hover:bg-blue-600 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:bg-blue-300"
          disabled={isLoading || !input.trim()}
        >
          Send
        </button>
      </form>
    </div>
  )
}

