from fastapi import FastAPI, HTTPException
import sqlite3
from typing import List, Dict, Any
from address import BibleAddressParser, VersesQueryBuilder, CommentariesQueryBuilder
import os

app = FastAPI()
DB_PATH = os.getenv("DB_PATH", "pl.SQLite3")

def query_db(query: str) -> List[Dict[str, Any]]:
    try:
        connection = sqlite3.connect(DB_PATH)
        connection.row_factory = sqlite3.Row
        cursor = connection.cursor()
        cursor.execute(query)
        results = [dict(row) for row in cursor.fetchall()]
        connection.close()
        return results
    except sqlite3.Error as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

# Endpoints
@app.get("/verses/")
def get_verses(address: str):
    parsed_addresses = BibleAddressParser(address).parse()
    query = VersesQueryBuilder(parsed_addresses).query()
    results = query_db(query)
    if not results:
        raise HTTPException(status_code=404, detail="Verse not found.")
    return results

@app.get("/commentaries/")
def get_commentaries(address: str):
    parsed_addresses = BibleAddressParser(address).parse()
    query = CommentariesQueryBuilder(parsed_addresses).query()
    results = query_db(query)
    if not results:
        raise HTTPException(status_code=404, detail="No commentaries found.")
    return results

@app.get("/navigation/")
def get_navigation(address: str):
    parsed_addresses = BibleAddressParser(address).parse()
    query = VersesQueryBuilder(parsed_addresses).query()
    current_verse = query_db(query)
    if not current_verse:
        raise HTTPException(status_code=404, detail="Verse not found.")

    next_query = """
        SELECT address FROM _all_verses 
        WHERE address > ? ORDER BY book_number, chapter, verse LIMIT 1
    """
    prev_query = """
        SELECT address FROM _all_verses 
        WHERE address < ? ORDER BY book_number DESC, chapter DESC, verse DESC LIMIT 1
    """

    next_verse = query_db(next_query, (address,))
    prev_verse = query_db(prev_query, (address,))

    return {
        "current": address,
        "previous": prev_verse[0]["address"] if prev_verse else None,
        "next": next_verse[0]["address"] if next_verse else None
    }
