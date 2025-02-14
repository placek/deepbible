from processor import BibleEmbeddingProcessor
from search_api import BibleSearchAPI
import os

collection_name = os.getenv("DEEPBIBLE_COLLECTION", "bible_collection")
qdrant_url = os.getenv("DEEPBIBLE_QDRANT_URL", "http://qdrant:6333")
databases = os.getenv("DEEPBIBLE_DATABASES", "PAU,NA28,VULG").split(",")
bible_databases_url = os.getenv("DEEPBIBLE_DATABASES_URL", "https://raw.githubusercontent.com/placek/bible-databases/master")
batch_size = int(os.getenv("DEEPBIBLE_BATCH_SIZE", 500))
device = os.getenv("DEEPBIBLE_DEVICE", "cpu")

processor = BibleEmbeddingProcessor(collection_name=collection_name,
                                    qdrant_url=qdrant_url,
                                    databases=databases,
                                    bible_databases_url=bible_databases_url,
                                    batch_size=batch_size, device=device)

app = BibleSearchAPI(processor=processor).get_app()
