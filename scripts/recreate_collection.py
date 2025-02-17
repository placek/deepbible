import os
from qdrant_client import QdrantClient
from qdrant_client.http import models

if __name__ == "__main__":
    collection_name = os.getenv("DEEPBIBLE_COLLECTION", "bible_collection")
    qdrant_url = os.getenv("DEEPBIBLE_QDRANT_URL", "http://qdrant:6333")

    print(f"(Re)creating collection '{collection_name}'...")
    QdrantClient(url=qdrant_url).recreate_collection(collection_name=collection_name, vectors_config=models.VectorParams(size=768, distance="Cosine"))

