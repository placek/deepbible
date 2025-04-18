 # DeepBible

 DeepBible is a pipeline for downloading, processing, and training language models on biblical texts from ph4.org. It supports fetching multiple translations, grouping them by language, merging them into unified SQLite databases, generating helper SQL functions and materialized views, uploading to PostgreSQL, embedding verses via an Ollama LLaMA model, and fine-tuning a LLaMA-based model with LoRA.

 ## Features
 - Download translations (SQLite3) from ph4.org.
 - Extract and group databases by language (default: Polish (`pl`), Latin (`la`), Koine Greek (`grc`)).
 - Merge grouped databases into a single SQLite3 database per language.
 - Generate SQL helper functions and materialized views for sanitized verse text.
 - Upload merged data tables (`_sources`, `_books`, `_all_verses`) to PostgreSQL schemas.
 - Embed verses using an Ollama LLaMA model and store vector embeddings in PostgreSQL.
 - (todo) Export verse data to JSONL and train a LoRA model on top of a base LLaMA model.
 - (todo) Convert the fine-tuned model to GGUF for use with Ollama.

 ## Prerequisites
 - [direnv](https://direnv.net/) (optional, for environment variable management)
 - [Nix](https://nixos.org/) (optional, for reproducible development environment via `shell.nix`)
 - `curl`, `p7zip` (`p7zip-full`)
 - `sqlite3`, `sqlitebrowser` (for inspection)
 - PostgreSQL server with [pgvector](https://github.com/pgvector/pgvector) extension
 - Python 3 with:
   - `psycopg2`
   - `requests`
   - `tqdm`
   - `regex`
   - `datasets`
   - `transformers`
   - `peft`
 - [Ollama](https://ollama.ai/) (for embeddings)
 - Base LLaMA model weights (managed via Ollama)

 ## Setup
 1. Clone the repository:
    ```bash
    git clone git@github.com:placek/deepbible.git
    cd deepbible
    ```
 2. Set environment variables for PostgreSQL and Ollama. Create a `.env` file in the project root:
    ```bash
    POSTGRES_DB=deepbible
    POSTGRES_USER=postgres
    POSTGRES_PASSWORD=secret
    POSTGRES_HOST=localhost
    POSTGRES_PORT=5432
    OLLAMA_HOST=localhost
    ```
    Load the variables with:
    ```bash
    source .env
    ```
    Or use `direnv` by adding to `.envrc`:
    ```bash
    dotenv .env
    ```
 3. Enter the development environment:
    ```bash
    nix-shell
    ```
    Or install dependencies manually:
    ```bash
    sudo apt-get update
    sudo apt-get install -y sqlite3 p7zip-full postgresql python3 python3-pip
    pip3 install psycopg2 requests tqdm regex datasets transformers peft
    ```

 ## Usage
 ### 1. Fetch and extract translations
 ```bash
 make fetch
 ```
 ### 2. Group by language
 ```bash
 make data/grouped/pl
 make data/grouped/la
 make data/grouped/grc
 ```
 ### 3. Merge databases
 ```bash
 make data/merged/pl.SQLite3
 make data/merged/la.SQLite3
 make data/merged/grc.SQLite3
 ```
 ### 4. Upload to PostgreSQL
 ```bash
 make upload
 ```
 This uploads the `_sources`, `_books`, and `_all_verses` tables to schemas named by each language code.
 ### 5. Embed verses
 ```bash
 make embed
 ```
 Embeds sanitized verses via Ollama and stores them in `public._verse_embeddings`.
 ### 6. Train LoRA model
 ```bash
 python3 scripts/train.py <model_id> <output_dir> data/merged/*.SQLite3
 ```
 - `model_id`: base LLaMA model (e.g., `NousResearch/Llama-2-7b-hf`)
 - `output_dir`: directory for training outputs and model artifacts
 ### 7. Use the fine-tuned model
 ```bash
 ollama create bible-l3 -f <output_dir>/Modelfile
 ollama run bible-l3
 ```

 ## Directory Structure
 ```
 .
 ├── Makefile            # Pipeline tasks (fetch, group, merge, upload, embed)
 ├── shell.nix           # Nix development shell
 ├── main_sources.json   # Main source per language
 ├── helpers.sql         # Generated SQL helpers and views
 ├── data/               # Downloads, extracted, grouped, merged databases
 ├── scripts/            # Python scripts for upload, embed, train
 ├── TODO.md             # Roadmap and feature list
 └── README.md           # Project overview and usage
 ```

 ## Contributing
 Contributions are welcome! Please open issues or pull requests.
