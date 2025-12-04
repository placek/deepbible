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
	  source_map=$$(mktemp); \
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
	  echo "  chapter_string_ps TEXT," >> $$tmp_sql; \
	  echo "  UNIQUE(name)" >> $$tmp_sql; \
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
	  echo "DROP TABLE IF EXISTS _dictionary_entries;" >> $$tmp_sql; \
	  echo "CREATE TABLE _dictionary_entries (" >> $$tmp_sql; \
	  echo "  language TEXT NOT NULL," >> $$tmp_sql; \
	  echo "  source_number INTEGER NOT NULL," >> $$tmp_sql; \
	  echo "  topic TEXT NOT NULL," >> $$tmp_sql; \
	  echo "  definition TEXT," >> $$tmp_sql; \
	  echo "  lexeme TEXT," >> $$tmp_sql; \
	  echo "  transliteration TEXT," >> $$tmp_sql; \
	  echo "  pronunciation TEXT," >> $$tmp_sql; \
	  echo "  short_definition TEXT," >> $$tmp_sql; \
	  echo "  PRIMARY KEY (language, source_number, topic)" >> $$tmp_sql; \
	  echo ");" >> $$tmp_sql; \
	  \
	  idx=1; \
	  dbs=$$(find "$<" -type f -name '*.SQLite3' | sort); \
	  for db in $$dbs; do \
	    name=$$(basename "$$db" .SQLite3 | cut -d. -f1); \
	    source_idx=$$(awk -v target="$$name" '$$1 == target { print $$2; exit }' "$$source_map"); \
	    if [ -z "$$source_idx" ]; then \
	      source_idx=$$idx; \
	      echo "$$name $$idx" >> "$$source_map"; \
	      idx=$$((idx+1)); \
	    fi; \
	    echo "ATTACH '$$db' AS source;" >> $$tmp_sql; \
	    has_info=$$(sqlite3 "$$db" "SELECT 1 FROM sqlite_master WHERE type='table' AND name='info' LIMIT 1;"); \
	    if [ "$$has_info" = "1" ]; then \
	      info_description_expr="(SELECT value FROM source.info WHERE name='description')"; \
	      info_detailed_expr="(SELECT value FROM source.info WHERE name='detailed_info')"; \
	      info_origin_expr="(SELECT value FROM source.info WHERE name='origin')"; \
	      info_chapter_string_expr="(SELECT value FROM source.info WHERE name='chapter_string')"; \
	      info_chapter_string_ps_expr="(SELECT value FROM source.info WHERE name='chapter_string_ps')"; \
	    else \
	      info_description_expr="NULL"; \
	      info_detailed_expr="NULL"; \
	      info_origin_expr="NULL"; \
	      info_chapter_string_expr="NULL"; \
	      info_chapter_string_ps_expr="NULL"; \
	    fi; \
	    \
	    echo "INSERT OR IGNORE INTO _sources (id, language, source_number, name, description_short, description_long, origin, chapter_string, chapter_string_ps)" >> $$tmp_sql; \
	    echo "SELECT ('$*/' || $$source_idx) AS id," >> $$tmp_sql; \
	    echo "       '$*'         AS language," >> $$tmp_sql; \
	    echo "       $$source_idx AS source_number," >> $$tmp_sql; \
	    echo "       '$$name'    AS name," >> $$tmp_sql; \
	    echo "       $${info_description_expr} AS description_short," >> $$tmp_sql; \
	    echo "       $${info_detailed_expr} AS description_long," >> $$tmp_sql; \
	    echo "       $${info_origin_expr} AS origin," >> $$tmp_sql; \
	    echo "       $${info_chapter_string_expr} AS chapter_string," >> $$tmp_sql; \
	    echo "       $${info_chapter_string_ps_expr} AS chapter_string_ps;" >> $$tmp_sql; \
	    \
	    has_books=$$(sqlite3 "$$db" "SELECT 1 FROM sqlite_master WHERE type='table' AND name='books' LIMIT 1;"); \
	    if [ "$$has_books" = "1" ]; then \
	      echo "INSERT OR IGNORE INTO _books (id, language, source_number, book_number, short_name, long_name)" >> $$tmp_sql; \
	      echo "SELECT ('$*/' || $$source_idx || '/' || b.book_number) AS id," >> $$tmp_sql; \
	      echo "       '$*'       AS language," >> $$tmp_sql; \
	      echo "       $$source_idx AS source_number," >> $$tmp_sql; \
	      echo "       b.book_number, b.short_name, COALESCE(b.long_name, b.short_name) AS long_name" >> $$tmp_sql; \
	      echo "FROM source.books b;" >> $$tmp_sql; \
	    fi; \
	    \
	    has_stories=$$(sqlite3 "$$db" "SELECT 1 FROM sqlite_master WHERE type='table' AND name='stories' LIMIT 1;"); \
	    if [ "$$has_stories" = "1" ]; then \
	      has_story_title=$$(sqlite3 "$$db" "SELECT 1 FROM pragma_table_info('stories') WHERE name='title' LIMIT 1;"); \
	      if [ "$$has_story_title" = "1" ]; then \
	        stories_title_expr="s.title"; \
	      else \
	        has_story_text=$$(sqlite3 "$$db" "SELECT 1 FROM pragma_table_info('stories') WHERE name='text' LIMIT 1;"); \
	        if [ "$$has_story_text" = "1" ]; then \
	          stories_title_expr="s.text"; \
	        else \
	          stories_title_expr="NULL"; \
	        fi; \
	      fi; \
	      echo "INSERT INTO _stories (language, source_number, book_number, chapter, verse, title)" >> $$tmp_sql; \
	      echo "SELECT" >> $$tmp_sql; \
	      echo "  '$*' AS language," >> $$tmp_sql; \
	      echo "  CAST($$source_idx AS INTEGER) AS source_number," >> $$tmp_sql; \
	      echo "  s.book_number," >> $$tmp_sql; \
	      echo "  s.chapter," >> $$tmp_sql; \
	      echo "  s.verse," >> $$tmp_sql; \
	      echo "  $${stories_title_expr} AS title" >> $$tmp_sql; \
	      echo "FROM source.stories s" >> $$tmp_sql; \
	      echo "WHERE s.book_number IS NULL" >> $$tmp_sql; \
	      echo "   OR (" >> $$tmp_sql; \
	      echo "        TRIM(CAST(s.book_number AS TEXT)) != ''" >> $$tmp_sql; \
	      echo "        AND TRIM(CAST(s.book_number AS TEXT)) GLOB '[0-9][0-9]*'" >> $$tmp_sql; \
	      echo "       );" >> $$tmp_sql; \
	    fi; \
	    \
	    has_verses=$$(sqlite3 "$$db" "SELECT 1 FROM sqlite_master WHERE type='table' AND name='verses' LIMIT 1;"); \
	    if [ "$$has_verses" = "1" ] && [ "$$has_books" = "1" ]; then \
	      echo "INSERT INTO _all_verses (" >> $$tmp_sql; \
	      echo "  id, language, source, book, book_name, address," >> $$tmp_sql; \
	      echo "  source_number, book_number, chapter, verse, text)" >> $$tmp_sql; \
	      echo "SELECT" >> $$tmp_sql; \
	      echo "  ('$*/' || $$source_idx || '/' || v.book_number || '/' || v.chapter || '/' || v.verse) AS id," >> $$tmp_sql; \
	      echo "  '$*' AS language," >> $$tmp_sql; \
	      echo "  (SELECT '$$name') AS source," >> $$tmp_sql; \
	      echo "  b.short_name AS book," >> $$tmp_sql; \
	      echo "  COALESCE(b.long_name, b.short_name) AS book_name," >> $$tmp_sql; \
	      echo "  (b.short_name || ' ' || v.chapter || ',' || v.verse) AS address," >> $$tmp_sql; \
	      echo "  CAST($$source_idx AS INTEGER)        AS source_number," >> $$tmp_sql; \
	      echo "  CAST(v.book_number AS INTEGER) AS book_number," >> $$tmp_sql; \
	      echo "  CAST(v.chapter     AS INTEGER) AS chapter," >> $$tmp_sql; \
	      echo "  CAST(v.verse       AS INTEGER) AS verse," >> $$tmp_sql; \
	      echo "  v.text" >> $$tmp_sql; \
	      echo "FROM source.verses v" >> $$tmp_sql; \
	      echo "JOIN source.books  b ON b.book_number = v.book_number;" >> $$tmp_sql; \
	    fi; \
	    \
	    has_dictionary=$$(sqlite3 "$$db" "SELECT 1 FROM sqlite_master WHERE type='table' AND name='dictionary' LIMIT 1;"); \
	    if [ "$$has_dictionary" = "1" ]; then \
	      has_dict_lexeme=$$(sqlite3 "$$db" "SELECT 1 FROM pragma_table_info('dictionary') WHERE name='lexeme' LIMIT 1;"); \
	      if [ "$$has_dict_lexeme" = "1" ]; then dict_lexeme_expr="d.lexeme"; else dict_lexeme_expr="NULL"; fi; \
	      has_dict_transliteration=$$(sqlite3 "$$db" "SELECT 1 FROM pragma_table_info('dictionary') WHERE name='transliteration' LIMIT 1;"); \
	      if [ "$$has_dict_transliteration" = "1" ]; then dict_transliteration_expr="d.transliteration"; else dict_transliteration_expr="NULL"; fi; \
	      has_dict_pronunciation=$$(sqlite3 "$$db" "SELECT 1 FROM pragma_table_info('dictionary') WHERE name='pronunciation' LIMIT 1;"); \
	      if [ "$$has_dict_pronunciation" = "1" ]; then dict_pronunciation_expr="d.pronunciation"; else dict_pronunciation_expr="NULL"; fi; \
	      has_dict_short_definition=$$(sqlite3 "$$db" "SELECT 1 FROM pragma_table_info('dictionary') WHERE name='short_definition' LIMIT 1;"); \
	      if [ "$$has_dict_short_definition" = "1" ]; then dict_short_definition_expr="d.short_definition"; else dict_short_definition_expr="NULL"; fi; \
	      echo "INSERT INTO _dictionary_entries (" >> $$tmp_sql; \
	      echo "  language, source_number, topic, definition, lexeme, transliteration, pronunciation, short_definition)" >> $$tmp_sql; \
	      echo "SELECT" >> $$tmp_sql; \
	      echo "  '$*' AS language," >> $$tmp_sql; \
	      echo "  CAST($$source_idx AS INTEGER) AS source_number," >> $$tmp_sql; \
	      echo "  d.topic," >> $$tmp_sql; \
	      echo "  d.definition," >> $$tmp_sql; \
	      echo "  $${dict_lexeme_expr} AS lexeme," >> $$tmp_sql; \
	      echo "  $${dict_transliteration_expr} AS transliteration," >> $$tmp_sql; \
	      echo "  $${dict_pronunciation_expr} AS pronunciation," >> $$tmp_sql; \
	      echo "  $${dict_short_definition_expr} AS short_definition" >> $$tmp_sql; \
	      echo "FROM source.dictionary d;" >> $$tmp_sql; \
	    fi; \
	    \
	    has_commentaries=$$(sqlite3 "$$db" "SELECT 1 FROM sqlite_master WHERE type='table' AND name='commentaries' LIMIT 1;"); \
	    if [ "$$has_commentaries" = "1" ]; then \
	      has_is_preceding=$$(sqlite3 "$$db" "SELECT 1 FROM pragma_table_info('commentaries') WHERE name='is_preceding' LIMIT 1;"); \
	      if [ "$$has_is_preceding" = "1" ]; then isp_col="c.is_preceding"; else isp_col="NULL"; fi; \
	      echo "INSERT INTO _commentaries (" >> $$tmp_sql; \
	      echo "  language, source_number, book_number, chapter_number_from, verse_number_from," >> $$tmp_sql; \
	      echo "  chapter_number_to, verse_number_to, is_preceding, marker, text)" >> $$tmp_sql; \
	      echo "SELECT" >> $$tmp_sql; \
	      echo "  '$*' AS language," >> $$tmp_sql; \
	      echo "  CAST($$source_idx AS TEXT) AS source_number," >> $$tmp_sql; \
	      echo "  c.book_number," >> $$tmp_sql; \
	      echo "  c.chapter_number_from," >> $$tmp_sql; \
	      echo "  c.verse_number_from," >> $$tmp_sql; \
	      echo "  c.chapter_number_to," >> $$tmp_sql; \
	      echo "  c.verse_number_to," >> $$tmp_sql; \
	      echo "  $${isp_col}," >> $$tmp_sql; \
	      echo "  c.marker," >> $$tmp_sql; \
	      echo "  COALESCE(c.text, '') AS text" >> $$tmp_sql; \
	      echo "FROM source.commentaries c;" >> $$tmp_sql; \
	    fi; \
	    \
	    echo "DETACH source;" >> $$tmp_sql; \
	  done; \
	  \
	  sqlite3 "$@" < "$$tmp_sql"; \
	  rm -f "$$tmp_sql" "$$source_map"; \
	}
