 # DeepBible

DeepBible is a pipeline for downloading and processing biblical texts from ph4.org. It supports fetching multiple translations, grouping them by language, merging them into unified SQLite databases, generating helper SQL functions and materialized views, uploading to PostgreSQL.

 ## Features
 - Download translations (SQLite3) from ph4.org.
 - Extract and group databases by language (default: Polish (`pl`), Latin (`la`), Koine Greek (`grc`), English (`en`)).
 - Merge grouped databases into a single SQLite3 database per language.
 - Generate SQL helper functions and materialized views for sanitized verse text.
 - Upload merged data tables (`_sources`, `_books`, `_all_verses`) to PostgreSQL schemas.

 ## Prerequisites
 - [direnv](https://direnv.net/) (optional, for environment variable management)
 - [Nix](https://nixos.org/) (optional, for reproducible development environment via `shell.nix`)
 - `curl`, `p7zip` (`p7zip-full`)
 - `sqlite3`, `sqlitebrowser` (for inspection)
 - PostgreSQL server

 ## Setup
 1. Clone the repository:
    ```bash
    git clone git@github.com:placek/deepbible.git
    cd deepbible
    ```
 2. Set environment variables for PostgreSQL and Ollama. Create a `.env` file in the project root:
    ```bash
    DATABASE_URL=postgresql://postgres:secret@localhost:5432/deepbible
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
    sudo apt-get install -y sqlite3 p7zip-full postgresql pgloader
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
 make data/grouped/en
 ```
 ### 3. Merge databases
 ```bash
 make data/merged/pl.SQLite3
 make data/merged/la.SQLite3
 make data/merged/grc.SQLite3
 make data/merged/en.SQLite3
 ```
 ### 4. Upload to PostgreSQL
 ```bash
 make upload
 ```
 This uploads the `_sources`, `_books`, and `_all_verses` tables to schemas named by each language code.

## Directory Structure
```
.
├── Makefile            # Pipeline tasks (fetch, group, merge, upload, embed)
├── build/              # Makefile components
├── frontend/           # PureScript + Halogen UI for browsing verses via PostgREST
├── sql/                # Raw SQL scripts for postgres
├── shell.nix           # Nix development shell
├── TODO.md             # Roadmap and feature list
└── README.md           # Project overview and usage
```

## Frontend previewer

A lightweight PureScript/Halogen interface lives in [`frontend/`](frontend/). It connects to the PostgREST schema defined in
[`sql/postgrest.sql`](sql/postgrest.sql) and lets you:

- Paste multiple Bible addresses separated by semicolons.
- Choose and freely reorder translations (sources) exposed in the `_all_sources` view.
- Display the resulting verses grouped by address, with verse references tucked to the margin so the text stays in focus.

See [`frontend/README.md`](frontend/README.md) for build and usage instructions.

 ## Contributing
 Contributions are welcome! Please open issues or pull requests.
