import os
import sqlite3
import psycopg2
import psycopg2.extras

DB_CONFIG = {
    "dbname": os.getenv("POSTGRES_DB"),
    "user": os.getenv("POSTGRES_USER"),
    "password": os.getenv("POSTGRES_PASSWORD"),
    "host": os.getenv("POSTGRES_HOST"),
    "port": os.getenv("POSTGRES_PORT"),
}

def get_db_connection():
    return psycopg2.connect(**DB_CONFIG)

def upload_table(sqlite_db_path, table_name, schema_name):
    print(f"Uploading {table_name} from {sqlite_db_path} to schema {schema_name}...")
    sqlite_conn = sqlite3.connect(sqlite_db_path)
    sqlite_cur = sqlite_conn.cursor()

    sqlite_cur.execute(f"SELECT * FROM {table_name}")
    rows = sqlite_cur.fetchall()
    col_names = [desc[0] for desc in sqlite_cur.description]

    pg_conn = get_db_connection()
    pg_conn.autocommit = True  # For CREATE SCHEMA outside transaction block
    pg_cur = pg_conn.cursor()

    # Create schema if it doesn't exist
    pg_cur.execute(f"CREATE SCHEMA IF NOT EXISTS {schema_name}")

    # Drop and recreate the table in the schema
    columns_ddl = ", ".join([f'"{col}" TEXT' for col in col_names])
    pg_cur.execute(f'DROP TABLE IF EXISTS "{schema_name}"."{table_name}" CASCADE')
    pg_cur.execute(f'CREATE TABLE "{schema_name}"."{table_name}" ({columns_ddl})')

    # Insert rows using batch insert
    psycopg2.extras.execute_batch(
        pg_cur,
        f'INSERT INTO "{schema_name}"."{table_name}" ({", ".join(col_names)}) VALUES ({", ".join(["%s"] * len(col_names))})',
        rows,
    )

    pg_cur.close()
    pg_conn.close()
    sqlite_cur.close()
    sqlite_conn.close()
    print(f">> Done uploading {schema_name}.{table_name}")

def main():
    import sys
    if len(sys.argv) != 2:
        print("Usage: python upload_sqlite_to_postgres.py path/to/merged/lang.SQLite3")
        return

    sqlite_db_path = sys.argv[1]
    lang_code = os.path.splitext(os.path.basename(sqlite_db_path))[0]

    upload_table(sqlite_db_path, "_sources", lang_code)
    upload_table(sqlite_db_path, "_books", lang_code)
    upload_table(sqlite_db_path, "_all_verses", lang_code)

if __name__ == "__main__":
    main()
