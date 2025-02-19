import { NextResponse } from "next/server"

export async function POST(req: Request) {
  try {
    const { message, sessionId } = await req.json()
    const webhookUrl = process.env.CHAT_WEBHOOK_URL

    if (!webhookUrl) {
      console.error("CHAT_WEBHOOK_URL is not configured")
      return NextResponse.json({ error: "Webhook URL not configured" }, { status: 500 })
    }

    console.log("Sending message to webhook:", message)

    const webhookResponse = await fetch(webhookUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        chatInput: message,
        sessionId: sessionId,
        action: "sendMessage",
      }),
    })

    if (!webhookResponse.ok) {
      console.error("Webhook response not ok:", webhookResponse.status)
      throw new Error(`Webhook responded with status: ${webhookResponse.status}`)
    }

    const responseData = await webhookResponse.json()
    console.log("Webhook response:", responseData)

    if (typeof responseData.output === "string") {
      return NextResponse.json({ response: responseData.output })
    } else {
      console.error("Unexpected response format:", responseData)
      return NextResponse.json({ error: "Invalid response format from webhook" }, { status: 500 })
    }
  } catch (error) {
    console.error("Error in chat API:", error)
    return NextResponse.json({ error: "Failed to process chat request" }, { status: 500 })
  }
}

