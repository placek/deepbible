import sqlite3
import os
import uuid
from sentence_transformers import SentenceTransformer
from qdrant_client import QdrantClient
from qdrant_client.http import models
from tqdm import tqdm
import re

class DeepBibleEmbeddingProcessor:
    def __init__(self, model_name=None, collection_name=None, qdrant_url=None, database=None, target_dir=None, batch_size=None, device=None):
        self.collection_name = collection_name
        self.database = database.replace("'", "_")
        self.batch_size = batch_size
        self.target_dir = target_dir
        self.client = QdrantClient(url=qdrant_url)
        self.model = SentenceTransformer(model_name, device=device)

    def sqlite_path(self):
        return os.path.join(self.target_dir, f"{self.database}.SQLite3")

    # Create an SQLite query to fetch verses from database
    def fetch_verses_sql(self):
        return f"""
        SELECT b.short_name || ' ' || v.chapter || '.' || v.verse AS reference,
               'textus' AS category,
               '{self.database.lower()}' AS source,
               v.text AS text
        FROM verses v
        JOIN books b ON v.book_number = b.book_number
        ORDER BY b.book_number, v.chapter, v.verse;
        """

    # Remove any XML-like tags from text
    def sanitize(self, text):
        return re.sub(r"<[^>]+>", "", text)

    # Fetch verses from database
    def fetch_verses(self):
        conn = sqlite3.connect(self.sqlite_path())
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        print(f"Fetching verses from {self.database}...")
        cursor.execute(self.fetch_verses_sql())
        verses = [dict(row) for row in cursor.fetchall()]
        print(f"- loaded {len(verses)} verses from SQLite.")
        conn.close()
        return verses

    # Generate embeddings for verses
    def generate_embeddings(self):
        verses = self.fetch_verses()
        print("Generating embeddings...")
        texts = [self.sanitize(v["text"]) for v in verses]  # Use first source as main text
        embeddings = self.model.encode(texts, show_progress_bar=True).tolist()
        return [verses, embeddings]

    # Upsert embeddings into Qdrant
    def upsert_to_qdrant(self):
        verses, vectors = self.generate_embeddings()
        ids = [str(uuid.uuid4()) for _ in range(len(vectors))]  # Unique IDs

        print("Upserting data into Qdrant...")

        for i in tqdm(range(0, len(ids), self.batch_size), desc="Upserting batches"):
            batch_ids = ids[i:i + self.batch_size]
            batch_vectors = vectors[i:i + self.batch_size]
            batch_payloads = verses[i:i + self.batch_size]

            self.client.upsert(
                collection_name=self.collection_name,
                points=models.Batch(
                    ids=batch_ids,
                    vectors=batch_vectors,
                    payloads=batch_payloads
                )
            )

    # Run the processor
    def run(self):
        self.upsert_to_qdrant()
        print("Done! Embeddings have been inserted into Qdrant.")


if __name__ == "__main__":
    model_name = os.getenv("DEEPBIBLE_MODEL", "sentence-transformers/all-mpnet-base-v2")
    collection_name = os.getenv("DEEPBIBLE_COLLECTION", "bible_collection")
    qdrant_url = os.getenv("DEEPBIBLE_QDRANT_URL", "http://qdrant:6333")
    databases = os.getenv("DEEPBIBLE_DATABASES", "PAU,NA28,VULG").split(",")
    batch_size = int(os.getenv("DEEPBIBLE_BATCH_SIZE", 500))
    device = os.getenv("DEEPBIBLE_DEVICE", "cpu")
    target_dir = os.getenv("DEEPBIBLE_TARGET_DIR", "/bibles")

    for db in databases:
        DeepBibleEmbeddingProcessor(model_name=model_name,
                                    collection_name=collection_name,
                                    qdrant_url=qdrant_url,
                                    database=db,
                                    target_dir=target_dir,
                                    batch_size=batch_size,
                                    device=device).run()
