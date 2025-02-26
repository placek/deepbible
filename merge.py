import os
import sys
import sqlite3
import re
import glob
import shutil

verses_view_sql = []
commentaries_view_sql = []

def create_sources(cursor):
    print("Creating _sources table...")
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS _sources (source_number NUM, name TEXT,
        relation TEXT, description_short TEXT, description_long TEXT, origin
        TEXT, chapter_string TEXT, chapter_string_ps TEXT, PRIMARY KEY
        (source_number));
    """)
    cursor.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_sources ON _sources (source_number, name);")

def insert_source(cursor, index, name, relation):
    cursor.execute(f"""
        INSERT INTO _sources (
            source_number, name, relation, description_short, description_long, 
            origin, chapter_string, chapter_string_ps
        )
        SELECT 
            {index} AS source_number,
            '{name}' AS name,
            '{relation}' AS relation,
            (SELECT value FROM source.info WHERE name = 'description') AS description_short,
            (SELECT value FROM source.info WHERE name = 'detailed_info') AS description_long,
            (SELECT value FROM source.info WHERE name = 'origin') AS origin,
            (SELECT value FROM source.info WHERE name = 'chapter_string') AS chapter_string,
            (SELECT value FROM source.info WHERE name = 'chapter_string_ps') AS chapter_string_ps;
    """)

def copy_books(cursor):
    print(f"- Copying books...")
    cursor.execute(f"CREATE TABLE _books AS SELECT * FROM source.books_all;")

def copy_verses(cursor, index, name):
    print(f"- Copying verses...")
    table_name = f"verses_{index:02d}"
    cursor.execute(f"CREATE TABLE {table_name} AS SELECT * FROM source.verses;")
    verses_view_sql.append(f"SELECT '{index}' AS source_number, book_number, chapter, verse, text FROM {table_name}")
    insert_source(cursor, index, name, table_name)

def copy_commentaries(cursor, index, name):
    print(f"- Copying commentaries...")
    table_name = f"commentaries_{index:02d}"
    cursor.execute(f"CREATE TABLE {table_name} AS SELECT * FROM source.commentaries;")
    commentaries_view_sql.append(f"SELECT '{index}' AS source_number, book_number, chapter_number_from, verse_number_from, chapter_number_to, verse_number_to, marker, text FROM {table_name}")
    insert_source(cursor, index, name, table_name)

def copy_dictionary(cursor, index, name):
    print(f"- Copying dictionary...")
    table_name = f"dictionary_{index:02d}"
    cursor.execute(f"CREATE TABLE {table_name} AS SELECT * FROM source.dictionary;")
    insert_source(cursor, index, name, table_name)

def copy_words(cursor, index, name):
    print(f"- Copying words...")
    table_name = f"words_{index:02d}"
    cursor.execute(f"CREATE TABLE {table_name} AS SELECT * FROM source.words;")
    insert_source(cursor, index, name, table_name)

def process_source(cursor, index, main_db_path, db_path):
    name = os.path.basename(db_path).replace(".SQLite3", "")
    print(f"Processing: {name}")
    cursor.execute(f"ATTACH '{db_path}' AS source;")
    if db_path == main_db_path:
        copy_books(cursor)
    if re.search(r"\.commentaries\.SQLite3$", db_path):
        copy_commentaries(cursor, index, name)
    elif re.search(r"\.dictionary\.SQLite3$", db_path):
        copy_dictionary(cursor, index, name)
        try:
            copy_words(cursor, index, name)
        except:
            print(f"                  ...no words found!")
    else:
        copy_verses(cursor, index, name)
    cursor.execute("COMMIT;")
    cursor.execute("DETACH source;")

def copy_cross_references(cursor):
    print(f"Copying _all_references...")
    references_db_path = "cross_references.SQLite3"
    cursor.execute("CREATE TABLE IF NOT EXISTS _all_references (address TEXT, address_from TEXT, address_to TEXT, rate NUM);")
    cursor.execute(f"ATTACH '{references_db_path}' AS ref;")
    cursor.execute("""
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
    cursor.execute("COMMIT;")
    cursor.execute("DETACH ref;")

def create_all_verses_view(cursor):
    print("Creating view _all_verses...")
    cursor.execute(f"""
        CREATE VIEW _all_verses AS
        SELECT v.*,
               (b.short_name || ' ' || v.chapter || ',' || v.verse) AS address,
               s.name AS source
        FROM ({' UNION ALL '.join(verses_view_sql)}) v
        JOIN _sources s ON v.source_number = s.source_number
        JOIN _books b ON v.book_number = b.book_number;
    """)

def create_all_commentaries_view(cursor):
    if commentaries_view_sql:
        print("Creating view _all_commentaries...")
        cursor.execute(f"""
            CREATE VIEW _all_commentaries AS 
            SELECT c.*, 
                   (b.short_name || ' ' || c.chapter_number_from || ',' || c.verse_number_from) AS address_from,
                   (b.short_name || ' ' || c.chapter_number_to || ',' || c.verse_number_to) AS address_to
            FROM ({' UNION ALL '.join(commentaries_view_sql)}) c
            JOIN _books b ON c.book_number = b.book_number;
        """)

def rename_db(db_path):
    os.rename(db_path, db_path.replace("'", "@"))
    return db_path.replace("'", "@")

def merge_databases(merged_db_path, main_db_path, db_files):
    if os.path.exists(merged_db_path):
        os.remove(merged_db_path)
    conn = sqlite3.connect(merged_db_path)
    cursor = conn.cursor()
    cursor.execute("PRAGMA foreign_keys=OFF;")
    create_sources(cursor)
    for index, db_path in enumerate(db_files):
        process_source(cursor, index, main_db_path, rename_db(db_path))
    copy_cross_references(cursor)
    create_all_verses_view(cursor)
    create_all_commentaries_view(cursor)
    conn.commit()
    conn.close()
    print(f"Merged database created: {merged_db_path}")

if __name__ == "__main__":
    LANGUAGE = sys.argv[1]
    MAIN = sys.argv[2]
    GROUPED_DIR = "grouped"
    MERGED_DIR = "merged"

    if not os.path.exists(MERGED_DIR):
        os.mkdir(MERGED_DIR)

    lang_dir = os.path.join(GROUPED_DIR, LANGUAGE)
    db_files = sorted(glob.glob(os.path.join(lang_dir, "*.SQLite3")))
    merged_db_path = os.path.join(MERGED_DIR, f"{LANGUAGE}.SQLite3")
    main_db_path = os.path.join(lang_dir, f"{MAIN}.SQLite3")

    merge_databases(merged_db_path, main_db_path, db_files)
