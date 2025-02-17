import sqlite3
import os
import requests
import zipfile
from sentence_transformers import SentenceTransformer
from qdrant_client import QdrantClient
from qdrant_client.http import models

class BibleEmbeddingProcessor:
    def __init__(self, collection_name=None, qdrant_url=None, databases=None, bible_databases_url=None, batch_size=None, device=None):
        self.collection_name = collection_name
        self.qdrant_url = qdrant_url
        self.databases = databases
        self.bible_databases_url = bible_databases_url
        self.batch_size = batch_size
        self.device = device

        self.data_dir = "/tmp/data"
        self.vector_size = 768
        os.makedirs(self.data_dir, exist_ok=True)
        self.client = QdrantClient(url=self.qdrant_url)
        self.model = SentenceTransformer("sentence-transformers/all-mpnet-base-v2", device=self.device)

    # Create collection in Qdrant
    def recreate_collection(self):
        print(f"Creating/recreating collection '{self.collection_name}' with vector size {self.vector_size}...")
        self.client.recreate_collection(
            collection_name=self.collection_name,
            vectors_config=models.VectorParams(size=self.vector_size, distance="Cosine")
        )

    # Download Bible database
    def download_database(self, db):
        print(f"Downloading {db}...")
        url = f"{self.bible_databases_url}/{db}.zip"
        response = requests.get(url)
        zip_path = os.path.join(self.data_dir, f"{db}.zip")
        with open(zip_path, "wb") as f:
            f.write(response.content)
        return zip_path

    # Extract Bible database
    def extract_database(self, db):
        zip_path = self.download_database(db)
        print(f"Extracting {zip_path}...")
        with zipfile.ZipFile(zip_path, "r") as zip_ref:
            zip_ref.extractall(self.data_dir)
        os.remove(zip_path)
        return os.path.join(self.data_dir, os.path.splitext(os.path.basename(zip_path))[0] + ".SQLite3")

    # Create an SQLite query to fetch verses from database
    def fetch_verses_sql(self, db):
        return f"""
        SELECT b.book_number || ':' || v.chapter || ':' || v.verse AS address,
               'textus' AS type,
               '{db.lower()}' AS sub_type,
               v.text AS text
        FROM verses v
        JOIN books b ON v.book_number = b.book_number
        ORDER BY b.book_number, v.chapter, v.verse;
        """

    # Fetch verses from database
    def fetch_verses(self, db):
        conn = sqlite3.connect(self.extract_database(db))
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        print("Fetching verses from {db}...")
        cursor.execute(self.fetch_verses_sql(db))
        verses = [dict(row) for row in cursor.fetchall()]
        print(f"- loaded {len(verses)} merged verses from SQLite.")
        conn.close()
        return verses

    # Generate embeddings for verses
    def generate_embeddings(self, db):
        verses = self.fetch_verses(db)
        print("Generating embeddings...")
        texts = [v["text"] for v in verses]  # Use first source as main text
        embeddings = self.model.encode(texts).tolist()
        return [verses, embeddings]

    # Upsert embeddings to Qdrant
    def upsert_to_qdrant(self, db):
        verses, vectors = self.generate_embeddings(db)
        print("Upserting data into Qdrant...")
        ids = list(range(len(vectors)))
        payloads = [{"address": verses[i]["address"], "type": verses[i]["type"], "sub_type": verses[i]["sub_type"]} for i in range(len(verses))]

        for i in range(0, len(ids), self.batch_size):
            print(f"Upserting batch {i} - {i + self.batch_size}...")
            self.client.upsert(
                collection_name=self.collection_name,
                points=models.Batch(
                    ids=ids[i:i + self.batch_size],
                    vectors=vectors[i:i + self.batch_size],
                    payloads=payloads[i:i + self.batch_size]
                )
            )

    # Run the processor
    def run(self):
        self.recreate_collection()
        for db in self.databases:
            self.upsert_to_qdrant(db)
        print("Done! Embeddings have been inserted into Qdrant.")

collection_name = os.getenv("DEEPBIBLE_COLLECTION", "bible_collection")
qdrant_url = os.getenv("DEEPBIBLE_QDRANT_URL", "http://qdrant:6333")
databases = os.getenv("DEEPBIBLE_DATABASES", "PAU,NA28,VULG").split(",")
bible_databases_url = os.getenv("DEEPBIBLE_DATABASES_URL", "https://raw.githubusercontent.com/placek/bible-databases/master")
batch_size = int(os.getenv("DEEPBIBLE_BATCH_SIZE", 500))
device = os.getenv("DEEPBIBLE_DEVICE", "cpu")

BibleEmbeddingProcessor(collection_name=collection_name,
                        qdrant_url=qdrant_url,
                        databases=databases,
                        bible_databases_url=bible_databases_url,
                        batch_size=batch_size, device=device).run()
