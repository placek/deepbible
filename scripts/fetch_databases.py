import os
import requests
import zipfile

class DeepBibleDatabaseFetcher:
    def __init__(self, database=None, bible_databases_url=None, target_dir=None):
        self.database = database
        self.bible_databases_url = bible_databases_url
        self.target_dir = target_dir

    def run(self):
        if not os.path.exists(self.sqlite_path()):
            self.download()
            self.extract()

    def zip_path(self):
        return os.path.join(self.target_dir, f"{self.database}.zip").replace("'", "_")

    def sqlite_path(self):
        return os.path.join(self.target_dir, f"{self.database}.SQLite3").replace("'", "_")

    def url(self):
        return f"{self.bible_databases_url}/{self.database}.zip"

    # Download Bible database
    def download(self):
        print(f"Downloading {self.database}...")
        with open(self.zip_path(), "wb") as f:
            f.write(requests.get(self.url()).content)

    # Extract Bible database
    def extract(self):
        print(f"Extracting {self.database}...")
        with zipfile.ZipFile(self.zip_path(), "r") as zip_ref:
            zip_ref.extractall(self.target_dir)
        os.rename(os.path.join(self.target_dir, f"{self.database}.SQLite3"), self.sqlite_path())


if __name__ == "__main__":
    databases = os.getenv("DEEPBIBLE_DATABASES", "PAU,NA28,VULG").split(",")
    bible_databases_url = os.getenv("DEEPBIBLE_DATABASES_URL", "https://raw.githubusercontent.com/placek/bible-databases/master")
    target_dir = os.getenv("DEEPBIBLE_TARGET_DIR", "/tmp/data")

    for db in databases:
        DeepBibleDatabaseFetcher(database=db,
                                 bible_databases_url=bible_databases_url,
                                 target_dir=target_dir).run()
