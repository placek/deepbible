import os
import sys
import sqlite3
import re
import glob
import shutil

LANGUAGE = sys.argv[1]
MAIN = sys.argv[2]
GROUPED_DIR = "grouped"
MERGED_DIR = "merged"

def merge_databases():
    # Check if the merged directory exists
    if not os.path.exists(MERGED_DIR):
        os.mkdir(MERGED_DIR)

    lang_dir = os.path.join(GROUPED_DIR, LANGUAGE)
    db_files = sorted(glob.glob(os.path.join(lang_dir, "*.SQLite3")))
    merged_db_path = os.path.join(MERGED_DIR, f"{LANGUAGE}.SQLite3")
    references_db_path = "cross_references.SQLite3"

    # Remove previous merged database if exists
    if os.path.exists(merged_db_path):
        os.remove(merged_db_path)

    # Use the "main" database
    main_db = os.path.join(lang_dir, f"{MAIN}.SQLite3")

    print(f"Main DB: {main_db}")
    print(f"Merging {len(db_files)} databases into {merged_db_path}")

    # Connect to new merged database
    merged_conn = sqlite3.connect(merged_db_path)
    merged_cursor = merged_conn.cursor()

    # Disable foreign keys (to avoid issues)
    merged_cursor.execute("PRAGMA foreign_keys=OFF;")

    # Create tables
    merged_cursor.execute("CREATE TABLE IF NOT EXISTS _info (source_number NUM, name TEXT, value TEXT);")
    merged_cursor.execute("CREATE TABLE IF NOT EXISTS _sources (source_number NUM, name TEXT, relation TEXT);")
    merged_cursor.execute("CREATE TABLE IF NOT EXISTS _all_references (address TEXT, address_from TEXT, address_to TEXT, rate NUM);")

    verses_view_sql = []
    commentaries_view_sql = []

    for index, db_path in enumerate(db_files):
        name = os.path.basename(db_path).replace(".SQLite3", "").replace("'", "@")
        os.rename(db_path, os.path.join(lang_dir, f"{name}.SQLite3"))
        db_path = os.path.join(lang_dir, f"{name}.SQLite3")

        print(f"Processing: {name}")

        # Attach database
        merged_cursor.execute(f"ATTACH '{db_path}' AS source;")

        # Copy info table
        print(f"- Copying info from {name}...")
        merged_cursor.execute(f"INSERT INTO _info SELECT {index}, name, value FROM source.info;")

        # If it's the main database, copy books
        if db_path == main_db:
            print(f"- Copying books (from main database: {MAIN})...")
            merged_cursor.execute(f"CREATE TABLE _books AS SELECT * FROM source.books_all;")

        # if db_path matches "*.commentaries.SQLite3"
        if re.search(r"\.commentaries\.SQLite3$", db_path):
            # Copy commentaries
            table_name = f"commentaries_{index:02d}"
            print(f"- Copying commentaries from {name}...")
            merged_cursor.execute(f"CREATE TABLE {table_name} AS SELECT * FROM source.commentaries;")
            commentaries_view_sql.append(f"SELECT '{index}' AS source_number, book_number, chapter_number_from, verse_number_from, chapter_number_to, verse_number_to, marker, text FROM {table_name}")
            merged_cursor.execute(f"INSERT INTO _sources (source_number, name, relation) VALUES ({index}, '{name}', '{table_name}');")
        elif re.search(r"\.dictionary\.SQLite3$", db_path):
            # Copy dictionary
            table_name = f"dictionary_{index:02d}"
            print(f"- Copying dictionary from {name}...")
            merged_cursor.execute(f"CREATE TABLE {table_name} AS SELECT * FROM source.dictionary;")
            merged_cursor.execute(f"INSERT INTO _sources (source_number, name, relation) VALUES ({index}, '{name}', '{table_name}');")
            # Copy words
            try:
                table_name = f"words_{index:02d}"
                print(f"- Copying words from {name}...")
                merged_cursor.execute(f"CREATE TABLE {table_name} AS SELECT * FROM source.words;")
                merged_cursor.execute(f"INSERT INTO _sources (source_number, name, relation) VALUES ({index}, '{name}', '{table_name}');")
            except:
                print(f"- No words table found in {name}")
        else:
            # Copy verses
            table_name = f"verses_{index:02d}"
            print(f"- Copying verses from {name}...")
            merged_cursor.execute(f"CREATE TABLE {table_name} AS SELECT * FROM source.verses;")
            verses_view_sql.append(f"SELECT '{index}' AS source_number, book_number, chapter, verse, text FROM {table_name}")
            merged_cursor.execute(f"INSERT INTO _sources (source_number, name, relation) VALUES ({index}, '{name}', '{table_name}');")

        # Commit changes before detaching
        merged_cursor.execute("COMMIT;")

        # Detach database
        merged_cursor.execute("DETACH source;")

    # Copy cross_references
    print(f"Copying cross_references...")
    merged_cursor.execute(f"ATTACH '{references_db_path}' AS ref;")
    merged_cursor.execute(f"""
        INSERT INTO _all_references
        SELECT (b.short_name || ' ' || r.chapter || ',' || r.verse) AS address,
               (b1.short_name || ' ' || r.c1 || ',' || r.v1) AS address_from,
               (b2.short_name || ' ' || r.c2 || ',' || r.v2) AS address_to,
               r.rate
        FROM ref.cross_references r
        JOIN _books b ON r.book_number = b.book_number
        JOIN _books b1 ON r.b1 = b1.book_number
        JOIN _books b2 ON r.b2 = b2.book_number;
    """)
    merged_cursor.execute("COMMIT;")
    merged_cursor.execute("DETACH ref;")

    # Create view combining all verses
    merged_cursor.execute(f"""
        CREATE VIEW _all_verses AS
        SELECT v.*,
               (b.short_name || ' ' || v.chapter || ',' || v.verse) AS address,
               s.name AS source
        FROM ({' UNION ALL '.join(verses_view_sql)}) v
        JOIN _sources s ON v.source_number = s.source_number
        JOIN _books b ON v.book_number = b.book_number;
    """)
    # Create view combining all commentaries
    if commentaries_view_sql:
        merged_cursor.execute(f"""
            CREATE VIEW _all_commentaries AS 
            SELECT c.*, 
                   (b.short_name || ' ' || c.chapter_number_from || ',' || c.verse_number_from) AS address_from,
                   (b.short_name || ' ' || c.chapter_number_to || ',' || c.verse_number_to) AS address_to
            FROM ({' UNION ALL '.join(commentaries_view_sql)}) c
            JOIN _books b ON c.book_number = b.book_number;
        """)

    # Commit and close
    merged_conn.commit()
    merged_conn.close()
    print(f"Merged database created: {merged_db_path}")

if __name__ == "__main__":
    merge_databases()
