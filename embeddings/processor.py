import sqlite3
import os
import numpy as np
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

        self.data_dir = "/app/data"
        self.conn = sqlite3.connect(":memory:")
        self.conn.row_factory = sqlite3.Row
        self.cursor = self.conn.cursor()
        self.client = QdrantClient(url=self.qdrant_url)
        self.model = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2", device=self.device)

    # Create collection in Qdrant
    def recreate_collection(self, embeddings):
        vector_size = embeddings.shape[1]
        print(f"Creating/recreating collection '{self.collection_name}' with vector size {vector_size}...")
        self.client.recreate_collection(
            collection_name=self.collection_name,
            vectors_config=models.VectorParams(size=vector_size, distance="Cosine")
        )

    # Download and extract Bible databases
    def download_and_extract_databases(self):
        print("Downloading and extracting Bible databases...")
        for db in self.databases:
            zip_path = os.path.join(self.data_dir, f"{db}.zip")
            db_path = os.path.join(self.data_dir, f"{db}.SQLite3")
            print(f"- downloading {db}...")
            url = f"{self.bible_databases_url}/{db}.zip"
            response = requests.get(url)
            with open(zip_path, "wb") as f:
                f.write(response.content)
            print(f"- extracting {db}.zip...")
            with zipfile.ZipFile(zip_path, "r") as zip_ref:
                zip_ref.extractall(self.data_dir)
            os.remove(zip_path)
            self.cursor.execute(f"ATTACH DATABASE '{db_path}' AS db{self.databases.index(db) + 1};")

    # Create an SQLite query to fetch verses from all databases
    def fetch_verses_sql(self):
        select_columns = ["b.book_number || ':' || v1.chapter || ':' || v1.verse AS verse_id",
                          "b.short_name AS book",
                          "v1.chapter",
                          "v1.verse"]
        join_statements = []
        for i, db in enumerate(self.databases, start=1):
            select_columns.append(f"v{i}.text AS text_{db.lower()}")
            if i > 1:
                join_statements.append(f"""
                LEFT JOIN db{i}.verses v{i}
                ON v1.book_number = v{i}.book_number
                AND v1.chapter = v{i}.chapter
                AND v1.verse = v{i}.verse
                """)
        return f"""
        SELECT {', '.join(select_columns)}
        FROM db1.verses v1
        JOIN db1.books b ON v1.book_number = b.book_number
        {''.join(join_statements)}
        ORDER BY b.book_number, v1.chapter, v1.verse;
        """

    # Fetch verses from all databases
    def fetch_verses(self):
        print("Fetching verses from SQLite...")
        self.cursor.execute(self.fetch_verses_sql())
        verses = [dict(row) for row in self.cursor.fetchall()]
        print(f"- loaded {len(verses)} merged verses from SQLite.")
        self.conn.close()
        return verses

    # Generate embeddings for verses
    def generate_embeddings(self, verses):
        print("Generating embeddings...")
        texts = [v[f"text_{self.databases[0].lower()}"] for v in verses]  # Use first source as main text
        embeddings = self.model.encode(texts)
        return embeddings

    # Upsert embeddings to Qdrant
    def upsert_to_qdrant(self, verses, embeddings):
        print("Upserting data into Qdrant...")
        vectors = embeddings.tolist()
        ids = list(range(len(vectors)))
        payloads = [{"verse_id": verses[i]["verse_id"], "book": verses[i]["book"],
                     "chapter": verses[i]["chapter"], "verse": verses[i]["verse"]}
                    for i in range(len(verses))]

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
        self.download_and_extract_databases()
        verses = self.fetch_verses()
        embeddings = self.generate_embeddings(verses)
        self.recreate_collection(embeddings)
        self.upsert_to_qdrant(verses, embeddings)
        print("Done! Embeddings have been inserted into Qdrant.")
