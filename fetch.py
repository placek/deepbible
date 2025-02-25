import sqlite3
import sys
import os
from sentence_transformers import SentenceTransformer
import numpy as np
import signal

data = sys.stdin.read()
print("Querying for:", data)

MERGED_DIR = "merged"
MODEL_NAME = os.getenv("MODEL_NAME", "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2")
MODEL_SIZE = int(os.getenv("MODEL_SIZE", 384))

# Load embedding model
model = SentenceTransformer(MODEL_NAME)

# Connect to SQLite database
database = sys.argv[1]
dbpath = os.path.join(MERGED_DIR, f"{database}.SQLite3")
sqlite_vec_path = os.getenv("SQLITE_VEC_PATH", "sqlite_vec")
conn = sqlite3.connect(dbpath)
cur = conn.cursor()

# Enable loading of extensions
conn.enable_load_extension(True)
conn.load_extension(sqlite_vec_path)

# Embed the query
query_vec = model.encode(data, convert_to_numpy=True).tolist()

# Fetch the results
cur.execute(f"""
    SELECT distance, source, address_from, address_to
    FROM _vectors
    WHERE vector MATCH '{query_vec}'
    ORDER BY distance
    LIMIT 20;
""")
results = cur.fetchall()

# Print the results
for result in results:
    print(result)
#     distance, source, address_from, address_to = result
#     cur.execute(f"SELECT text FROM _all_verses WHERE source = '{source}' AND address = '{address_from}';")
#     text = cur.fetchone()[0]
#     print(f"- {source:5s} - {address_from} ({distance}):", text)
