import os
import sys
import sqlite3
import re
import glob
import shutil

LANGUAGE = sys.argv[1]
MAIN = sys.argv[2]
GROUPED_DIR = "grouped"

def merge_databases():
    lang_dir = os.path.join(GROUPED_DIR, LANGUAGE)
    db_files = sorted(glob.glob(os.path.join(lang_dir, "*.SQLite3")))
    merged_db_path = f"{LANGUAGE}.db"

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

    # Create view combining all verses
    merged_cursor.execute(f"CREATE VIEW _all_verses AS {' UNION ALL '.join(verses_view_sql)};")
    # Create view combining all commentaries
    if commentaries_view_sql:
        merged_cursor.execute(f"CREATE VIEW _all_commentaries AS {' UNION ALL '.join(commentaries_view_sql)};")

    # Commit and close
    merged_conn.commit()
    merged_conn.close()
    print(f"Merged database created: {merged_db_path}")

if __name__ == "__main__":
    merge_databases()
