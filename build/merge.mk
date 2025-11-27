common_mk := build/common.mk
ifeq ($(origin $(common_mk)), undefined)
  $(eval $(common_mk) := included)
  include $(common_mk)
endif

.PRECIOUS: $(merged_dir)/%.SQLite3
.PHONY: clean-merged

clean-merged:
	-rm -rf $(merged_dir)

# creates necessary directories
$(merged_dir):
	@mkdir -p $@

# merges the SQLite3 databases for each language into one _all_verses table (no temp tables, no SQLite views)
$(merged_dir)/%.SQLite3: $(grouped_dir)/% | $(merged_dir)
	@{ \
	  tmp_sql=$$(mktemp); \
	  echo 'PRAGMA foreign_keys=OFF;' >> $$tmp_sql; \
	  \
	  echo "CREATE TABLE IF NOT EXISTS _sources (" >> $$tmp_sql; \
	  echo "  id TEXT NOT NULL," >> $$tmp_sql; \
	  echo "  language TEXT NOT NULL," >> $$tmp_sql; \
	  echo "  source_number INTEGER NOT NULL," >> $$tmp_sql; \
	  echo "  name TEXT," >> $$tmp_sql; \
	  echo "  description_short TEXT," >> $$tmp_sql; \
	  echo "  description_long TEXT," >> $$tmp_sql; \
	  echo "  origin TEXT," >> $$tmp_sql; \
	  echo "  chapter_string TEXT," >> $$tmp_sql; \
	  echo "  chapter_string_ps TEXT" >> $$tmp_sql; \
	  echo ");" >> $$tmp_sql; \
	  \
	  echo "CREATE TABLE IF NOT EXISTS _books (" >> $$tmp_sql; \
	  echo "  id TEXT NOT NULL," >> $$tmp_sql; \
	  echo "  language TEXT NOT NULL," >> $$tmp_sql; \
	  echo "  source_number INTEGER NOT NULL," >> $$tmp_sql; \
	  echo "  book_number INTEGER NOT NULL," >> $$tmp_sql; \
	  echo "  short_name TEXT," >> $$tmp_sql; \
	  echo "  long_name  TEXT" >> $$tmp_sql; \
	  echo ");" >> $$tmp_sql; \
	  \
	  echo "DROP TABLE IF EXISTS _all_verses;" >> $$tmp_sql; \
	  echo "CREATE TABLE _all_verses (" >> $$tmp_sql; \
	  echo "  id TEXT NOT NULL," >> $$tmp_sql; \
	  echo "  language TEXT NOT NULL," >> $$tmp_sql; \
	  echo "  source TEXT NOT NULL," >> $$tmp_sql; \
	  echo "  book TEXT NOT NULL," >> $$tmp_sql; \
	  echo "  book_name TEXT NOT NULL," >> $$tmp_sql; \
	  echo "  address TEXT NOT NULL," >> $$tmp_sql; \
	  echo "  source_number INTEGER NOT NULL," >> $$tmp_sql; \
	  echo "  book_number INTEGER NOT NULL," >> $$tmp_sql; \
	  echo "  chapter INTEGER NOT NULL," >> $$tmp_sql; \
	  echo "  verse INTEGER NOT NULL," >> $$tmp_sql; \
	  echo "  text TEXT" >> $$tmp_sql; \
	  echo ");" >> $$tmp_sql; \
	  \
	  echo "DROP TABLE IF EXISTS _stories;" >> $$tmp_sql; \
	  echo "CREATE TABLE _stories (" >> $$tmp_sql; \
	  echo "  language TEXT NOT NULL," >> $$tmp_sql; \
	  echo "  source_number INTEGER," >> $$tmp_sql; \
	  echo "  book_number NUMERIC," >> $$tmp_sql; \
	  echo "  chapter NUMERIC," >> $$tmp_sql; \
	  echo "  verse NUMERIC," >> $$tmp_sql; \
	  echo "  title TEXT" >> $$tmp_sql; \
	  echo ");" >> $$tmp_sql; \
	  \
	  echo "DROP TABLE IF EXISTS _commentaries;" >> $$tmp_sql; \
	  echo "CREATE TABLE _commentaries (" >> $$tmp_sql; \
	  echo "  language TEXT NOT NULL," >> $$tmp_sql; \
	  echo "  source_number TEXT," >> $$tmp_sql; \
	  echo "  book_number NUMERIC," >> $$tmp_sql; \
	  echo "  chapter_number_from NUMERIC," >> $$tmp_sql; \
	  echo "  verse_number_from NUMERIC," >> $$tmp_sql; \
	  echo "  chapter_number_to NUMERIC," >> $$tmp_sql; \
	  echo "  verse_number_to NUMERIC," >> $$tmp_sql; \
	  echo "  is_preceding NUMERIC," >> $$tmp_sql; \
	  echo "  marker TEXT," >> $$tmp_sql; \
	  echo "  text TEXT NOT NULL DEFAULT ''" >> $$tmp_sql; \
	  echo ");" >> $$tmp_sql; \
	  \
	  idx=0; \
	  dbs=$$(find "$<" -type f -name '*.SQLite3' ! -name '*.commentaries.SQLite3' | sort); \
	  for db in $$dbs; do \
	    name=$$(basename "$$db" .SQLite3); \
	    dot_count=$$(echo "$$name" | sed 's/[^.]//g' | wc -c | tr -d '[:space:]'); \
	    if [ "$$dot_count" -gt 1 ]; then continue; fi; \
	    cdb="$${db%.SQLite3}.commentaries.SQLite3"; \
	    \
	    echo "ATTACH '$$db' AS source;" >> $$tmp_sql; \
	    \
	    echo "INSERT INTO _sources (id, language, source_number, name, description_short, description_long, origin, chapter_string, chapter_string_ps)" >> $$tmp_sql; \
	    echo "SELECT ('$*/' || $$idx) AS id," >> $$tmp_sql; \
	    echo "       '$*'        AS language," >> $$tmp_sql; \
	    echo "       $$idx       AS source_number," >> $$tmp_sql; \
	    echo "       '$$name'    AS name," >> $$tmp_sql; \
	    echo "       (SELECT value FROM source.info WHERE name='description')," >> $$tmp_sql; \
	    echo "       (SELECT value FROM source.info WHERE name='detailed_info')," >> $$tmp_sql; \
	    echo "       (SELECT value FROM source.info WHERE name='origin')," >> $$tmp_sql; \
	    echo "       (SELECT value FROM source.info WHERE name='chapter_string')," >> $$tmp_sql; \
	    echo "       (SELECT value FROM source.info WHERE name='chapter_string_ps');" >> $$tmp_sql; \
	    \
	    echo "INSERT OR IGNORE INTO _books (id, language, source_number, book_number, short_name, long_name)" >> $$tmp_sql; \
	    echo "SELECT ('$*/' || $$idx || '/' || b.book_number) AS id," >> $$tmp_sql; \
	    echo "       '$*'  AS language," >> $$tmp_sql; \
	    echo "       $$idx AS source_number," >> $$tmp_sql; \
	    echo "       b.book_number, b.short_name, COALESCE(b.long_name, b.short_name) AS long_name" >> $$tmp_sql; \
	    echo "FROM source.books b;" >> $$tmp_sql; \
	    \
	    has_stories=$$(sqlite3 "$$db" "SELECT 1 FROM sqlite_master WHERE type='table' AND name='stories' LIMIT 1;"); \
	    if [ "$$has_stories" = "1" ]; then \
	      echo "INSERT INTO _stories (language, source_number, book_number, chapter, verse, title)" >> $$tmp_sql; \
	      echo "SELECT" >> $$tmp_sql; \
	      echo "  '$*' AS language," >> $$tmp_sql; \
	      echo "  CAST($$idx AS INTEGER) AS source_number," >> $$tmp_sql; \
	      echo "  s.book_number," >> $$tmp_sql; \
	      echo "  s.chapter," >> $$tmp_sql; \
	      echo "  s.verse," >> $$tmp_sql; \
	      echo "  s.title" >> $$tmp_sql; \
	      echo "FROM source.stories s;" >> $$tmp_sql; \
	    fi; \
	    \
	    echo "INSERT INTO _all_verses (" >> $$tmp_sql; \
	    echo "  id, language, source, book, book_name, address," >> $$tmp_sql; \
	    echo "  source_number, book_number, chapter, verse, text)" >> $$tmp_sql; \
	    echo "SELECT" >> $$tmp_sql; \
	    echo "  ('$*/' || $$idx || '/' || v.book_number || '/' || v.chapter || '/' || v.verse) AS id," >> $$tmp_sql; \
	    echo "  '$*' AS language," >> $$tmp_sql; \
	    echo "  (SELECT '$$name') AS source," >> $$tmp_sql; \
	    echo "  b.short_name AS book," >> $$tmp_sql; \
	    echo "  COALESCE(b.long_name, b.short_name) AS book_name," >> $$tmp_sql; \
	    echo "  (b.short_name || ' ' || v.chapter || ',' || v.verse) AS address," >> $$tmp_sql; \
	    echo "  CAST($$idx AS INTEGER)        AS source_number," >> $$tmp_sql; \
	    echo "  CAST(v.book_number AS INTEGER) AS book_number," >> $$tmp_sql; \
	    echo "  CAST(v.chapter     AS INTEGER) AS chapter," >> $$tmp_sql; \
	    echo "  CAST(v.verse       AS INTEGER) AS verse," >> $$tmp_sql; \
	    echo "  v.text" >> $$tmp_sql; \
	    echo "FROM source.verses v" >> $$tmp_sql; \
	    echo "JOIN source.books  b ON b.book_number = v.book_number;" >> $$tmp_sql; \
	    \
	    echo "DETACH source;" >> $$tmp_sql; \
	    \
	    if [ -f "$$cdb" ]; then \
	      has_is_preceding=$$(sqlite3 "$$cdb" "SELECT 1 FROM pragma_table_info('commentaries') WHERE name='is_preceding' LIMIT 1;"); \
	      if [ "$$has_is_preceding" = "1" ]; then isp_col="c.is_preceding"; else isp_col="NULL"; fi; \
	      echo "ATTACH '$$cdb' AS commentary;" >> $$tmp_sql; \
	      echo "INSERT INTO _commentaries (" >> $$tmp_sql; \
	      echo "  language, source_number, book_number, chapter_number_from, verse_number_from," >> $$tmp_sql; \
	      echo "  chapter_number_to, verse_number_to, is_preceding, marker, text)" >> $$tmp_sql; \
	      echo "SELECT" >> $$tmp_sql; \
	      echo "  '$*' AS language," >> $$tmp_sql; \
	      echo "  CAST($$idx AS TEXT) AS source_number," >> $$tmp_sql; \
	      echo "  c.book_number," >> $$tmp_sql; \
	      echo "  c.chapter_number_from," >> $$tmp_sql; \
	      echo "  c.verse_number_from," >> $$tmp_sql; \
	      echo "  c.chapter_number_to," >> $$tmp_sql; \
	      echo "  c.verse_number_to," >> $$tmp_sql; \
	      echo "  $${isp_col}," >> $$tmp_sql; \
	      echo "  c.marker," >> $$tmp_sql; \
	      echo "  c.text" >> $$tmp_sql; \
	      echo "FROM commentary.commentaries c;" >> $$tmp_sql; \
	      echo "DETACH commentary;" >> $$tmp_sql; \
	    fi; \
	    \
	    idx=$$((idx+1)); \
	  done; \
	  \
	  sqlite3 "$@" < "$$tmp_sql"; \
	  rm -f "$$tmp_sql"; \
	}
