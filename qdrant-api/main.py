from fastapi import FastAPI
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer
from qdrant_client import QdrantClient
import os

class SearchRequest(BaseModel):
    query: str
    top_k: int = 5

class BibleSearchAPI:
    def __init__(self, collection_name=None, qdrant_url=None, batch_size=None, device=None):
        self.collection_name = collection_name
        self.qdrant_url = qdrant_url
        self.batch_size = batch_size
        self.device = device

        self.client = QdrantClient(url=self.qdrant_url)
        self.model = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2", device=self.device)
        self.app = FastAPI()
        self.setup_routes()

    def setup_routes(self):
        @self.app.post("/search/")
        def search(request: SearchRequest):
            query_embedding = self.model.encode([request.query])[0]
            search_results = self.client.search(
                collection_name=self.collection_name,
                query_vector=query_embedding,
                limit=request.top_k
            )
            results = [ {**res.payload, "score": res.score} for res in search_results ]
            return {"query": request.query, "results": results}

    def get_app(self):
        return self.app

collection_name = os.getenv("DEEPBIBLE_COLLECTION", "bible_collection")
qdrant_url = os.getenv("DEEPBIBLE_QDRANT_URL", "http://qdrant:6333")
databases = os.getenv("DEEPBIBLE_DATABASES", "PAU,NA28,VULG").split(",")
bible_databases_url = os.getenv("DEEPBIBLE_DATABASES_URL", "https://raw.githubusercontent.com/placek/bible-databases/master")
batch_size = int(os.getenv("DEEPBIBLE_BATCH_SIZE", 500))
device = os.getenv("DEEPBIBLE_DEVICE", "cpu")

app = BibleSearchAPI(collection_name=collection_name, qdrant_url=qdrant_url, batch_size=batch_size, device=device).get_app()
