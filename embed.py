import sqlite3
import sys
import os
from sentence_transformers import SentenceTransformer
import numpy as np
import signal

# Load embedding model
model = SentenceTransformer("sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2")

# Connect to SQLite database
database = sys.argv[1]
sqlite_vec_path = os.getenv("SQLITE_VEC_PATH", "sqlite_vec")
conn = sqlite3.connect(database)
cur = conn.cursor()

# Enable loading of extensions
conn.enable_load_extension(True)
conn.load_extension(sqlite_vec_path)

# Create the virtual table
cur.execute("DROP TABLE IF EXISTS _vectors;")
cur.execute("""
    CREATE VIRTUAL TABLE _vectors
    USING vec0(type TEXT,
               source_number INTEGER,
               book_number INTEGER,
               chapter_number_from INTEGER,
               verse_number_from INTEGER,
               chapter_number_to INTEGER,
               verse_number_to INTEGER,
               vector float[384]
               );
""")
conn.commit()
print("Virtual table (re)created successfully!")

# Global state tracker
current_state = {
    "type": None,
    "source_number": None,
    "book_number": None,
    "chapter_number": None
}

# Signal handler to print current processing state
def print_status(signum, frame):
    print(f"\nCurrently processing -> Type: {current_state['type']}, "
          f"Source Number: {current_state['source_number']}, "
          f"Book Number: {current_state['book_number']}, "
          f"Chapter Number: {current_state['chapter_number']}")

# Register the signal handler
signal.signal(signal.SIGTSTP, print_status)  # Triggered by Ctrl+Z

# Function to insert vectors
def insert_vector(type_, source_number, book_number, chapterf, versef, chaptert, verset, text):
    try:
        vector = model.encode(text, convert_to_numpy=True).tolist()
        cur.execute(f"""
            INSERT INTO _vectors (vector, type, source_number, book_number,
                                  chapter_number_from, verse_number_from,
                                  chapter_number_to, verse_number_to)
            VALUES ('{str(vector)}', '{type_}', {source_number}, {book_number}, {chapterf}, {versef}, {chaptert}, {verset});
        """)
        conn.commit()
    except Exception as e:
        print(f"\nError: {e}, while processing -> {text}")

# Process _all_verses
print("Processing _all_verses...")
cur.execute("SELECT source_number, book_number, chapter, verse, text FROM _all_verses")
for row in cur.fetchall():
    source_number, book_number, chapter, verse, text = row
    current_state["type"] = "verse"
    current_state["source_number"] = source_number
    current_state["book_number"] = book_number
    current_state["chapter_number"] = chapter
    insert_vector("verse", source_number, book_number, chapter, verse, chapter, verse, text)
    sys.stdout.write(".")
    sys.stdout.flush()

# Process _all_commentaries
print("\nProcessing _all_commentaries...")
cur.execute("""
    SELECT source_number, book_number, chapter_number_from, verse_number_from, 
           chapter_number_to, verse_number_to, text 
    FROM _all_commentaries
""")
for row in cur.fetchall():
    source_number, book_number, chapter_from, verse_from, chapter_to, verse_to, text = row
    current_state["type"] = "commentary"
    current_state["source_number"] = source_number
    current_state["book_number"] = book_number
    current_state["chapter_number"] = chapter_from
    insert_vector("commentary", source_number, book_number, chapter_from, verse_from, chapter_to, verse_to, text)
    sys.stdout.write(".")
    sys.stdout.flush()

conn.close()
print("\nVector database created successfully!")
