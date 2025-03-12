"use client"

export default function AddressedTile({ source, address, content }) {
  return (
    <div key={address} className="border rounded-lg p-4">
      <div className="font-semibold mb-2">{address}</div>
      <div className="text-sm font-medium text-muted-foreground mb-1">{source}</div>
      <div dangerouslySetInnerHTML={{ __html: content }} />
    </div>
  )
}
