from fastapi import FastAPI, HTTPException
import sqlite3
from typing import List, Dict, Any
from address import BibleAddressParser, VersesQueryBuilder, CommentariesQueryBuilder
import os
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allow all methods (GET, POST, etc.)
    allow_headers=["*"],  # Allow all headers
)
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
@app.get("/verses")
def get_verses(address: str):
    parsed_addresses = BibleAddressParser(address).parse()
    query = VersesQueryBuilder(parsed_addresses).query()
    results = query_db(query)
    if not results:
        raise HTTPException(status_code=404, detail="Verse not found.")
    return results

@app.get("/commentaries")
def get_commentaries(address: str):
    parsed_addresses = BibleAddressParser(address).parse()
    query = CommentariesQueryBuilder(parsed_addresses).query()
    results = query_db(query)
    if not results:
        raise HTTPException(status_code=404, detail="No commentaries found.")
    return results
