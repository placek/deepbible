import os
import json
import uuid
import psycopg2
from tqdm import tqdm
from sentence_transformers import SentenceTransformer

DB_CONFIG = {
    "dbname": os.getenv("POSTGRES_DB"),
    "user": os.getenv("POSTGRES_USER"),
    "password": os.getenv("POSTGRES_PASSWORD"),
    "host": os.getenv("POSTGRES_HOST", "localhost"),
    "port": os.getenv("POSTGRES_PORT", 5432),
}
BATCH_SIZE = int(os.getenv("BATCH_SIZE", 256))

model = SentenceTransformer("BAAI/bge-m3")

def get_db_connection():
    return psycopg2.connect(**DB_CONFIG)

def get_embedding(text):
    return model.encode(text).tolist()

def get_batch(cur, offset):
    cur.execute(f"""
        SELECT sv.id AS id,
               sv.text AS content,
               jsonb_build_object(
                 'id', sv.id,
                 'language', sv.language,
                 'source', sv.source,
                 'address', sv.address,
                 'loc', jsonb_build_object('s', sv.source_number,
                                           'b', sv.book_number,
                                           'c', sv.chapter,
                                           'v', sv.verse)
                ) AS metadata
        FROM public._sanitized_verses sv
        LEFT JOIN public._verse_embeddings ve
               ON ve.metadata->>'id' = sv.id
        WHERE sv.text IS NOT NULL
          AND ve.id IS NULL
        ORDER BY sv.id
        OFFSET %s LIMIT %s
    """, (offset, BATCH_SIZE))
    return cur.fetchall()

def main():
    conn = get_db_connection()
    cur = conn.cursor()
    offset = 0
    while True:
        rows = get_batch(cur, offset)

        if not rows:
            break

        for verse_id, content, metadata in tqdm(rows, desc=f"Embedding verses [offset {offset}]"):
            try:
                embedding = get_embedding(content)
                if not embedding:
                    print(f">> skipping verse {verse_id}: invalid embedding")
                    continue
                if not isinstance(embedding, list) or len(embedding) == 0:
                    print(f">> skipping verse {verse_id}: empty embedding")
                    continue
                cur.execute("""
                    INSERT INTO public._verse_embeddings (id, embedding, content, metadata)
                    VALUES (%s, %s, %s, %s)
                """, (str(uuid.uuid4()), embedding, content, json.dumps(metadata)))

            except Exception as e:
                print(f"E> error embedding verse {verse_id}: {e}")
                conn.rollback()

        conn.commit()
        offset += BATCH_SIZE

    cur.close()
    conn.close()

if __name__ == "__main__":
    main()
