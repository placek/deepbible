from fastapi import FastAPI
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer
from qdrant_client import QdrantClient
from qdrant_client.models import Filter, FieldCondition, MatchValue
import os

class SearchRequest(BaseModel):
    query: str
    limit: int = 50
    category: str = None
    source: str = None

class VerseRequest(BaseModel):
    address: str
    limit: int = 50
    source: str = "pau"

class DeepBibleAPI:
    def __init__(self, model_name=None, collection_name=None, qdrant_url=None, batch_size=None, device=None, target_dir=None):
        self.collection_name = collection_name
        self.batch_size = batch_size
        self.target_dir = target_dir

        self.client = QdrantClient(url=qdrant_url)
        self.model = SentenceTransformer(model_name, device=device)
        self.app = FastAPI()
        self.setup_routes()

    def sqlite_path(self, db):
        return os.path.join(self.target_dir, f"{db}.SQLite3")

    def setup_routes(self):
        # Fetch verses from database
        @self.app.post("/verses")
        async def verses(request: VerseRequest):
            filters = Filter(must=[FieldCondition(key="category",
                                         match=MatchValue(value="textus")),
                          FieldCondition(key="source",
                                         match=MatchValue(value=request.source)),
                          FieldCondition(key="reference",
                                         match=MatchValue(value=request.address))])
            search_results = self.client.scroll(
                collection_name=self.collection_name,
                scroll_filter=filters,
                limit=request.limit
            )
            results = [ {**res.payload} for res in search_results[0] ]
            return {"address": request.address, "results": results}

        # Find similar verses
        @self.app.post("/similar_verses")
        def get_similar_verses(request: VerseRequest):
            results = self.client.scroll(
                collection_name=self.collection_name,
                scroll_filter=Filter(must=[FieldCondition(key="reference",
                                                          match=MatchValue(value=request.address)),
                                           FieldCondition(key="source",
                                                          match=MatchValue(value=request.source))
                                           ]),
                limit=1
            )
            query_embedding = self.model.encode([results[0][0].payload["text"]])[0]
            search_results = self.client.search(
                collection_name=self.collection_name,
                query_vector=query_embedding,
                limit=request.limit,
                query_filter=Filter(must=[FieldCondition(key="category",
                                                         match=MatchValue(value="textus")),
                                          FieldCondition(key="source",
                                                         match=MatchValue(value=request.source))])
            )
            results = [ {**res.payload, "score": res.score} for res in search_results ]
            return {"address": request.address, "results": results}

        # Search by vector proximity
        @self.app.post("/search")
        async def search(request: SearchRequest):
            query_embedding = self.model.encode([request.query])[0]
            conditions = []
            if request.category:
                conditions.append(
                    FieldCondition(key="category", match=MatchValue(value=request.category))
                )
            if request.source:
                conditions.append(
                    FieldCondition(key="source", match=MatchValue(value=request.source))
                )
            filters = Filter(must=conditions) if conditions else None
            search_results = self.client.search(
                collection_name=self.collection_name,
                query_vector=query_embedding,
                limit=request.limit,
                query_filter=filters
            )
            results = [{**res.payload, "score": res.score} for res in search_results]
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
target_dir = os.getenv("DEEPBIBLE_TARGET_DIR", "/bibles")

app = DeepBibleAPI(model_name=model_name,
                   collection_name=collection_name,
                   qdrant_url=qdrant_url,
                   batch_size=batch_size,
                   device=device,
                   target_dir=target_dir).run()
