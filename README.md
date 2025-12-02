# DeepBible

DeepBible helps you assemble multilingual Bible datasets and load them into PostgreSQL for search and analysis. It focuses on simple make targets so you can fetch sources, merge them per language, and publish helper views that are ready to query.

## What you can do
- Fetch Bible translations from ph4.org as SQLite3 files.
- Group source databases by language (Polish `pl`, Latin `la`, Koine Greek `grc`, English `en`, or any language present in the sources).
- Merge grouped databases into a single SQLite3 file per language with unified verse, book, source, story, and commentary tables.
- Download and prepare cross references for verse-to-verse links.
- Upload merged tables to PostgreSQL schemas named after each language code.
- Generate helper SQL for materialized views, unified `public` views, and full-text search indexes.

## Before you start
- PostgreSQL server and `psql` access.
- `curl`, `p7zip` (`p7zip-full`), `sqlite3`.
- Optional: `direnv` and Nix (`nix-shell`) if you want the supplied environment.
- Set `DATABASE_URL` (e.g., `postgresql://postgres:secret@localhost:5432/deepbible`).

## Typical workflow
1) Enter the project directory and load environment variables (e.g., `source .env` or use `direnv`).
2) Fetch all available translations and extract them:
```bash
make fetch
```
3) Group translations by language. Run once per language you want:
```bash
make data/grouped/pl
make data/grouped/la
make data/grouped/grc
make data/grouped/en
```
4) Merge grouped databases into one SQLite3 file per language:
```bash
make data/merged/pl.SQLite3
make data/merged/la.SQLite3
make data/merged/grc.SQLite3
make data/merged/en.SQLite3
```
5) Build cross-reference data (optional but useful for linking verses):
```bash
make cross-references
```
6) Upload merged tables to PostgreSQL (creates schemas like `pl`, `la`, etc.):
```bash
make upload
```
7) Apply helper SQL to publish `public` views and text search indexes:
```bash
make apply-helpers
```

## What gets created
- **SQLite outputs:** one merged SQLite3 database per language in `data/merged/` plus an optional cross-reference database in `data/cross_references/`.
- **PostgreSQL schemas:** `_sources`, `_books`, `_all_verses`, `_stories`, and `_commentaries` tables per language schema.
- **Public helpers:** materialized view `public._all_verses` with full-text search, views for books and sources, and union views for stories and commentaries.

## Need help?
Run `make` targets with `-n` to see the commands without executing them, or open an issue/PR with questions or suggestions.
