from fastapi import FastAPI
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer
from qdrant_client import QdrantClient
import os

# Define the request model
class SearchRequest(BaseModel):
    query: str
    top_k: int = 5

class BibleSearchAPI:
    def __init__(self, processor=None):
        self.processor = processor

        self.processor.run()

        self.collection_name = self.processor.collection_name
        self.qdrant_url = self.processor.qdrant_url
        self.device = self.processor.device
        self.model = self.processor.model
        self.client = self.processor.client
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
