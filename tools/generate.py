import os
import re
import requests
import zipfile
import sqlite3
import shutil
from bs4 import BeautifulSoup
from urllib.parse import urljoin

# Base URL
BASE_URL = "https://www.ph4.org/b4_index.php"
DOWNLOAD_DIR = "data/downloads"
EXTRACT_DIR = "data/extracted"
GROUPED_DIR = "data/grouped"

# Ensure directories exist
os.makedirs(DOWNLOAD_DIR, exist_ok=True)
os.makedirs(EXTRACT_DIR, exist_ok=True)
os.makedirs(GROUPED_DIR, exist_ok=True)

# Step 1: Scrape webpage for download links
response = requests.get(BASE_URL)
soup = BeautifulSoup(response.text, "html.parser")

# Find all links that match the href pattern
download_links = [urljoin(BASE_URL, a["href"]) for a in soup.find_all("a", href=True) if "_dl.php" in a["href"]]

# Step 2: Download each zip file
for link in download_links:
    name = re.search(r"a=([^&]+)&", link).group(1)
    zip_filename = os.path.join(DOWNLOAD_DIR, name + ".zip")
    if os.path.exists(zip_filename):
        print(f"Skipping: {link} as {zip_filename} already exists")
        continue
    print(f"Downloading: {link} to {zip_filename}")

    with requests.get(link, stream=True) as r:
        with open(zip_filename, "wb") as f:
            for chunk in r.iter_content(chunk_size=8192):
                f.write(chunk)

# Step 3: Extract files
for zip_file in os.listdir(DOWNLOAD_DIR):
    if zip_file.endswith(".zip"):
        zip_path = os.path.join(DOWNLOAD_DIR, zip_file)
        extract_path = os.path.join(EXTRACT_DIR, os.path.splitext(zip_file)[0])
        if os.path.exists(extract_path):
            print(f"Skipping: {zip_path} as {extract_path} already exists")
            continue
        print(f"Extracting: {zip_path}")
        os.makedirs(extract_path, exist_ok=True)

        with zipfile.ZipFile(zip_path, "r") as zip_ref:
            zip_ref.extractall(extract_path)

# Step 4: Filter SQLite3 files
sqlite_files = []
for root, _, files in os.walk(EXTRACT_DIR):
    for file in files:
        if file.endswith(".SQLite3"):
            sqlite_path = os.path.join(root, file)
            sqlite_files.append(sqlite_path)

# Step 5: Query SQLite3 files and group them by language
for db_path in sqlite_files:
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT value FROM info WHERE name = 'language' LIMIT 1;")
        result = cursor.fetchone()
        conn.close()

        if result:
            language = result[0]
            language_dir = os.path.join(GROUPED_DIR, language)
            os.makedirs(language_dir, exist_ok=True)
            shutil.move(db_path, os.path.join(language_dir, os.path.basename(db_path)))
            print(f"Move: {db_path} to {language_dir}")
        else:
            print(f"Language not found in {db_path}")

    except Exception as e:
        print(f"Error processing {db_path}: {e}")

print("Processing complete.")
