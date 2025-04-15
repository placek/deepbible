import sqlite3
import sys
import os
from sentence_transformers import SentenceTransformer
import numpy as np
import signal

data = sys.stdin.read()
print("Querying for:", data)

MERGED_DIR = "data/merged"
MODEL_NAME = os.getenv("MODEL_NAME", "models/paraphrase-multilingual-MiniLM-L12-v2")
MODEL_SIZE = int(os.getenv("MODEL_SIZE", 384))
LIMIT = int(os.getenv("LIMIT", 20))

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
    SELECT e.distance, v.address, v.text
    FROM ( SELECT distance, source, address_from
           FROM _vectors
           WHERE vector MATCH '{query_vec}'
             AND type = 'verse'
             AND k = {LIMIT}
           ORDER BY distance) e
    JOIN _all_verses v
    ON e.source = v.source AND e.address_from = v.address;
""")
results = cur.fetchall()

# Print the results
for result in results:
    print(result)
