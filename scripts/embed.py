import os
import json
import uuid
import requests
import psycopg2
from tqdm import tqdm

DB_CONFIG = {
    "dbname": os.getenv("POSTGRES_DB"),
    "user": os.getenv("POSTGRES_USER"),
    "password": os.getenv("POSTGRES_PASSWORD"),
    "host": os.getenv("POSTGRES_HOST", "localhost"),
    "port": os.getenv("POSTGRES_PORT", 5432),
}
OLLAMA_HOST = os.getenv("OLLAMA_HOST", "localhost")
BATCH_SIZE = 256

def get_db_connection():
    return psycopg2.connect(**DB_CONFIG)

def get_embedding(text):
    response = requests.post(f"http://{OLLAMA_HOST}:11434/api/embeddings", json={
        "model": "llama3",
        "prompt": text
    })
    response.raise_for_status()
    return response.json()["embedding"]

def create_table_if_not_exists(cur):
    cur.execute("""
        CREATE EXTENSION IF NOT EXISTS vector;
        CREATE TABLE IF NOT EXISTS public._verse_embeddings (
            id UUID PRIMARY KEY,
            embedding vector(4096),
            text TEXT,
            metadata JSONB
        )
    """)

def main():
    conn = get_db_connection()
    cur = conn.cursor()

    create_table_if_not_exists(cur)

    offset = 0
    while True:
        cur.execute("""
            SELECT id, text, language, source, address
            FROM public._sanitized_verses
            WHERE text IS NOT NULL
            OFFSET %s LIMIT %s
        """, (offset, BATCH_SIZE))
        rows = cur.fetchall()

        if not rows:
            break

        for verse_id, text, lang, source, addr in tqdm(rows, desc=f"Embedding verses [offset {offset}]"):
            # Skip if already embedded
            cur.execute("""
                SELECT 1 FROM public._verse_embeddings
                WHERE metadata->>'id' = %s
                LIMIT 1
            """, (verse_id,))
            if cur.fetchone():
                continue

            try:
                embedding = get_embedding(text)

                if not embedding or not isinstance(embedding, list) or len(embedding) == 0:
                    print(f"Skipping verse {verse_id}: empty or invalid embedding")
                    continue

                metadata = {
                    "id": verse_id,
                    "language": lang,
                    "source": source,
                    "address": addr
                }
                cur.execute("""
                    INSERT INTO public._verse_embeddings (id, embedding, text, metadata)
                    VALUES (%s, %s, %s, %s)
                """, (str(uuid.uuid4()), embedding, text, json.dumps(metadata)))

            except Exception as e:
                print(f"Error embedding verse {verse_id}: {e}")
                conn.rollback()

        conn.commit()
        offset += BATCH_SIZE

    cur.close()
    conn.close()

if __name__ == "__main__":
    main()
