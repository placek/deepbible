import sqlite3
import sys
import os
from sentence_transformers import SentenceTransformer
import numpy as np
import signal

MERGED_DIR = "data/merged"
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

# Create the virtual table
cur.execute("DROP TABLE IF EXISTS _vectors;")
cur.execute(f"""
    CREATE VIRTUAL TABLE _vectors
    USING vec0(type TEXT,
               source TEXT,
               address_from TEXT,
               address_to TEXT,
               vector float[{MODEL_SIZE}]
               );
""")
conn.commit()
print("Virtual table (re)created successfully!")

# Global state tracker
current_state = {
    "type": None,
    "source": None,
    "address": None
}

# Signal handler to print current processing state
def print_status(signum, frame):
    print(f"\n{current_state['type']}: {current_state['source']}  {current_state['address']}")

# Register the signal handler
signal.signal(signal.SIGTSTP, print_status)  # Triggered by Ctrl+Z

# Function to insert vectors
def insert_vector(type_, source, address_from, address_to, text):
    current_state["type"] = type_
    current_state["source"] = source
    current_state["address"] = address_from
    try:
        vector = model.encode(text, convert_to_numpy=True).tolist()
        cur.execute(f"""
            INSERT INTO _vectors (vector, type, source, address_from, address_to)
            VALUES ('{str(vector)}', '{type_}', '{source}', '{address_from}', '{address_to}');
        """)
        conn.commit()
    except Exception as e:
        print(f"\nError: {e}, while processing -> {text}")

# Process _all_verses
print("Processing _all_verses...")
cur.execute("SELECT source, address, text FROM _all_verses")
for row in cur.fetchall():
    source, address, text = row
    insert_vector("verse", source, address, address, text)
    sys.stdout.write(".")
    sys.stdout.flush()
exit()

# Process _all_commentaries
print("\nProcessing _all_commentaries...")
cur.execute("""
    SELECT source_number, book_number, chapter_number_from, verse_number_from, 
           chapter_number_to, verse_number_to, text 
    FROM _all_commentaries
""")
for row in cur.fetchall():
    source_number, book_number, chapter_from, verse_from, chapter_to, verse_to, text = row
    insert_vector("commentary", source_number, book_number, chapter_from, verse_from, chapter_to, verse_to, text)
    sys.stdout.write(".")
    sys.stdout.flush()

conn.close()
print("\nVector database created successfully!")
