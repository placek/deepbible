# DeepBible

DeepBible is a full-stack Bible study application: a browser workspace for laying out pericopes from hundreds of translations across 8 languages, annotating them with Markdown notes, and pulling in lexical help, cross references, commentaries, and semantic search -- all without leaving the page.

The stack consists of a Makefile-driven data pipeline (download, merge, upload), a PostgreSQL database exposed via PostgREST, and a PureScript + Halogen single-page frontend.

## Project structure

```
.
├── build/            # Modular Makefile includes (download, merge, upload, helpers, frontend)
├── data/             # Downloaded, extracted, grouped, and merged Bible databases
│   ├── downloads/    # Raw .zip files from ph4.org
│   ├── extracted/    # Unzipped SQLite3 databases per translation
│   ├── grouped/      # Databases organized by language
│   ├── merged/       # Final merged SQLite3 per language
│   └── openbible/    # Cross-references dataset
├── frontend/         # PureScript SPA (Halogen)
│   ├── src/          # Source modules (~4,100 lines)
│   ├── styles/       # CSS (Solarized-inspired palette)
│   ├── index.html    # Entry point
│   └── flake.nix     # Nix flake for PureScript tooling
├── helpers/          # Generated SQL files combining all languages
├── sql/              # Source SQL: UI tables, errata, functions, PostgREST API
├── Makefile          # Root orchestration
├── shell.nix         # Nix dev environment
└── upload.load       # pgloader configuration template
```

## Quick start

### Frontend only

1. **Enter the development environment**
   ```bash
   nix develop   # or nix-shell
   ```
2. **Bundle the PureScript app**
   ```bash
   make frontend-build   # or: cd frontend && purs-nix bundle
   ```
3. **Serve the static files**
   ```bash
   make run
   # or: cd frontend && python3 -m http.server 8000
   ```
4. Open `http://localhost:8000`. The app loads pre-populated with John 3:16-17 in four translations.

While the dev shell is open you can run `watch` to re-bundle automatically on source changes.

### Full data pipeline

Requires PostgreSQL, pgloader, SQLite3, and network access. Configure database credentials in a `deepbible.env` file (loaded via `.envrc`):

```bash
export PGUSER=... PGPASSWORD=... PGHOST=... PGPORT=... PGDATABASE=...
```

Then run the full pipeline:

```bash
make all   # clean → download → merge → upload → apply-helpers
```

Or run stages individually:

| Command | Description |
|---------|-------------|
| `make download` | Download Bible translation zips from ph4.org |
| `make merge` | Merge per-language SQLite3 databases into unified tables |
| `make upload` | Migrate merged SQLite3 databases to PostgreSQL via pgloader |
| `make apply-helpers` | Generate and apply SQL views, functions, and API definitions |
| `make frontend-build` | Bundle the PureScript frontend |
| `make run` | Build frontend and start dev server on port 8000 |
| `make info` | Display project configuration |
| `make clean` | Remove all build artifacts |

## Data pipeline

The pipeline downloads Bible translation databases from ph4.org, covering 8 languages: Polish, Latin, Greek, English, Italian, Spanish, French, and German (600+ individual translations).

**Stages:**

1. **Download** (`build/download.mk`) -- fetches `.zip` archives per translation into `data/downloads/`.
2. **Extract** (`build/download.mk`) -- unzips SQLite3 databases into `data/extracted/`, then groups them by language into `data/grouped/`.
3. **Merge** (`build/merge.mk`) -- combines all databases for each language into a single SQLite3 file under `data/merged/`, creating unified tables: `_sources`, `_books`, `_all_verses`, `_stories`, `_commentaries`, `_dictionary_entries`.
4. **Cross references** (`build/cross_references.mk`) -- downloads the OpenBible cross-references dataset and maps references across all language databases.
5. **Upload** (`build/upload.mk`) -- migrates merged SQLite3 files to PostgreSQL using pgloader.
6. **Helpers** (`build/helpers.mk`) -- generates SQL that creates a `deepbible` schema with materialized views combining all languages, plus functions and PostgREST API definitions.

## Database & API

### Schema

The `deepbible` schema exposes these materialized views and tables:

| Object | Description |
|--------|-------------|
| `_all_verses` | Union of all verses across all languages (id, language, source, book, address, chapter, verse, text) |
| `_books` | Book metadata per language |
| `_sources` | Translation catalog (name, description, language) |
| `_commentaries` | Verse annotations |
| `_stories` | Narrative/pericope boundaries |
| `_dictionary_entries` | Lexical data (lemma, gloss, parsing, forms) |
| `_sheets` | Saved user workspaces (UUID, JSONB data, timestamp) |
| `_embeddings` | pgvector embeddings for semantic search (1024-dim, `snowflake-arctic-embed2` via Ollama) |

### SQL functions (`sql/12_functions.sql`)

**Text processing:**
- `text_without_format(text)` -- strips display tags (`<strong>`, `<b>`, `<br>`, etc.)
- `text_without_metadata(text)` -- strips metadata tags (`<S>` Strong's, `<m>` morphology, etc.)
- `raw_text(text)` -- removes all XML tags
- `collect_tags(text)` -- extracts metadata tags into JSONB

**Verse retrieval:**
- `parse_address(text)` -- parses Bible addresses (e.g., `Mk 5,1-20`) into book/chapter/verse tuples
- `fetch_verses_by_address(address, source)` -- retrieves formatted verses with optional language filtering
- `fetch_verse_with_metadata(verse_id)` -- returns verse plus extracted metadata

**Search:**
- `parse_search_phrase(text)` -- tokenizes `@SOURCE`, `~Address`, and free-text components
- `search_verses(phrase)` -- combines semantic search (pgvector cosine similarity) with address/source filtering
- `generate_embedding(text, model)` -- calls Ollama (`snowflake-arctic-embed2`) for 1024-dim vectors

**Reference data:**
- `fetch_cross_references(verse_id)` / `fetch_cross_references_by_address(address, source)`
- `fetch_commentaries(verse_id)`
- `fetch_rendered_stories(source, address)` -- story/pericope boundaries via materialized view
- `verse_dictionary(verse_id)` -- lexical entries (topic, word, meaning, parse, forms)

**Workspace management:**
- `upsert_sheet(id, data)` / `fetch_sheet(id)` -- save/load workspaces
- `cleanup_stale_sheets()` -- deletes untitled sheets older than 7 days

### PostgREST API (`sql/13_postgrest.sql`)

All functions are exposed as anonymous read-only RPC endpoints via PostgREST:

```
POST https://api.bible.placki.cloud/rpc/<function_name>
Headers: Accept-Profile: api, Content-Profile: api
```

No credentials are needed; calls are anonymous. Sheet upserts are the only write operation.

### Data corrections (`sql/11_errata.sql`)

~80+ targeted `UPDATE` statements that fix known data quality issues: malformed XML tags, broken Strong's number references, encoding artifacts, missing whitespace, and unwanted HTML elements -- primarily in Greek and Polish translations.

## Frontend

### Architecture

The frontend is a PureScript 0.15 single-page application using the Halogen UI framework. Key modules:

| Module | Role |
|--------|------|
| `App.Main` | Root component: manages item list, drag-and-drop, search, sheet persistence |
| `App.State` | Immutable app state type |
| `App.UrlState` | URL hash serialization (pako-compressed JSON) |
| `App.Markdown` | Sheet-to-Markdown export and download |
| `Pericope.Component` | Verse display, selection, source picker, cross-refs, dictionary |
| `Note.Component` | Markdown note editing (click to edit, Esc to save) |
| `Search.Component` | Search input with token highlighting and results |
| `Search.Highlight` | Renders `@SOURCE` (yellow) and `~Address` (red) tokens |
| `Infrastructure.Api` | HTTP client for all PostgREST RPC calls |
| `Infrastructure.LocalStorage` | Recently accessed sheets stored in browser |
| `Domain.Bible.Types` | Core domain types (Verse, CrossReference, Commentary, Story, etc.) |
| `Domain.Pericope.Types` | Pericope type (address, source, verses, selected IDs) |
| `Domain.Note.Types` | Note type (id, Markdown content) |

### Styling

CSS uses a Solarized-inspired color scheme defined in `frontend/styles/colors.css`:

- Source/translation labels in gold, addresses in red, Jesus' words in orange
- Cross-references in blue, stories in magenta, footnotes/Strong's in purple
- Selected verses highlighted in green
- Greek text rendered with a custom `newathu.ttf` font
- Responsive layout with mobile adjustments at 570px

## UI guide

### Search

The search bar highlights tokens inline: `@CODE` (yellow) filters by source/translation, `~Book 1,1-10` (red) pins an address range. Free text triggers semantic search via pgvector embeddings.

Examples:
- `love` -- semantic search across all translations
- `@NASB love` -- search within NASB only
- `~J 3` -- browse John chapter 3
- `@NVUL ~J 3 Deus amor` -- combine all filters

Press **Enter** to search, **Esc** to hide results. Click a result to add it as a pericope card.

### Workspace items

The workspace is an ordered list of **pericopes** and **notes**. Between every item a `+` button inserts a note. Each item header has a drag handle, duplicate button, and remove button. Dragging uses native HTML5 events.

### Pericope cards

- **Address & source editing**: click to edit inline. The source picker groups translations by language and filters as you type.
- **Verse grid**: HTML-rendered verses from the backend (red letters, paragraph markers preserved). Click a verse to toggle selection.
- **Selected address chip**: contiguous selection shows a computed address in the margin. Click it to spawn a new pericope from the selection.
- **Cross references & stories**: single-verse selection triggers lookups. Click a cross-reference or story link to fetch those verses.
- **Dictionary lane**: single-verse selection fetches lexical entries. Click a lemma to expand parsing info, gloss, and related forms.
- **Batch input**: enter multiple addresses (one per line) to insert several pericopes at once.

### Notes

Markdown-backed. Click the rendered body to edit; blur or **Esc** to exit. Notes can be duplicated, dragged, or deleted like any other item.

### Sharing & persistence

- State is serialized as pako-compressed JSON in the URL hash (`#state=...`). Copy the URL to share the exact arrangement including notes.
- Legacy `?pericopes=...` URLs are auto-upgraded to the new format.
- Browser history via `pushState` enables undo/redo for insertions and deletions.
- Workspaces can be saved as named sheets (persisted to the database). Recent sheets are tracked in browser local storage.
- Sheets can be exported as Markdown files.

## Development environment

The Nix shell (`shell.nix` + `frontend/flake.nix`) provides:

- **Data pipeline**: sqlite3, pgloader, pgformatter, postgresql, p7zip, rlwrap, sqlitebrowser
- **Frontend**: PureScript compiler, purs-nix, esbuild, Node.js, purescript-language-server, entr (file watcher)

### Generating embeddings

To generate semantic search embeddings for a specific source (requires a running Ollama instance with `snowflake-arctic-embed2`):

```bash
make embed-source SOURCE=BT_03
```
