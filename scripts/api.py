from fastapi import FastAPI
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer
from qdrant_client import QdrantClient
from qdrant_client.models import Filter
import os

class SearchRequest(BaseModel):
    query: str
    limit: int = 50

class DeepBibleAPI:
    def __init__(self, model_name=None, collection_name=None, qdrant_url=None, batch_size=None, device=None):
        self.collection_name = collection_name
        self.batch_size = batch_size

        self.client = QdrantClient(url=qdrant_url)
        self.model = SentenceTransformer(model_name, device=device)
        self.app = FastAPI()
        self.setup_routes()

    def setup_routes(self):
        @self.app.get("/full/")
        def full(request: SearchRequest):
            query_embedding = self.model.encode([request.query])[0]
            search_results = self.client.search(
                collection_name=self.collection_name,
                query_vector=query_embedding,
                limit=request.limit
            )
            results = [ {**res.payload, "score": res.score} for res in search_results ]
            return {"query": request.query, "results": results}

        @self.app.get("/textus/")
        def textus(request: SearchRequest):
            query_embedding = self.model.encode([request.query])[0]
            search_results = self.client.search(
                collection_name=self.collection_name,
                query_vector=query_embedding,
                limit=request.limit,
                query_filter=Filter(
                    must=[{"key": "type", "match": {"value": "textus"}}]
                )
            )
            results = [ {**res.payload, "score": res.score} for res in search_results ]
            return {"query": request.query, "results": results}

        @self.app.get("/commentary/")
        def commentary(request: SearchRequest):
            query_embedding = self.model.encode([request.query])[0]
            search_results = self.client.search(
                collection_name=self.collection_name,
                query_vector=query_embedding,
                limit=request.limit,
                query_filter=Filter(
                    must=[{"key": "type", "match": {"value": "commentary"}}]
                )
            )
            results = [ {**res.payload, "score": res.score} for res in search_results ]
            return {"query": request.query, "results": results}

    def run(self):
        return self.app

model_name = os.getenv("DEEPBIBLE_MODEL", "sentence-transformers/all-mpnet-base-v2")
collection_name = os.getenv("DEEPBIBLE_COLLECTION", "bible_collection")
qdrant_url = os.getenv("DEEPBIBLE_QDRANT_URL", "http://qdrant:6333")
databases = os.getenv("DEEPBIBLE_DATABASES", "PAU,NA28,VULG").split(",")
bible_databases_url = os.getenv("DEEPBIBLE_DATABASES_URL", "https://raw.githubusercontent.com/placek/bible-databases/master")
batch_size = int(os.getenv("DEEPBIBLE_BATCH_SIZE", 500))
device = os.getenv("DEEPBIBLE_DEVICE", "cpu")

app = DeepBibleAPI(model_name=model_name,
                   collection_name=collection_name,
                   qdrant_url=qdrant_url,
                   batch_size=batch_size,
                   device=device).run()
