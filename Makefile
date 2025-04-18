bible_sources_url := https://www.ph4.org

download_dir := data/downloads
extract_dir  := data/extracted
grouped_dir  := data/grouped
merged_dir   := data/merged
helpers_sql  := helpers.sql

langs       ?= pl la grc
# model_id     ?= NousResearch/Llama-2-7b-hf
# final_jsonl  := $(output_dir)/bible.jsonl
# gguf_path    := $(output_dir)/gguf

.PRECIOUS: $(download_dir)/%.zip $(extract_dir)/% $(grouped_dir)/% $(merged_dir)/%.SQLite3
.PHONY: fetch re-fetch clean upload-% upload apply-helpers # train

all:
	@echo "Read Makefile first to understand how to use it."

clean:
	-rm -rf $(merged_dir) download-list.txt failed.txt $(helpers_sql)

# fetches the list of available zip files
download-list.txt:
	curl -s "$(bible_sources_url)/b4_index.php" | \
	grep -oP 'href="_dl.php[^"]+"' | \
	sed 's/.*a=\([^&]\+\)&.*/\1/' | \
	sort > $@

$(download_dir) $(extract_dir) $(grouped_dir) $(merged_dir) $(output_dir):
	@mkdir -p $@

# downloads a target zip file containing a SQLite3 databases
$(download_dir)/%.zip: $(download_dir)
	curl -f -o "$@" "$(bible_sources_url)/_dl.php?back=bbl&a=$(basename $*)&b=mybible&c" || \
	echo "$(subst .zip,,$@)" >> failed.txt

# extracts the SQLite3 database from the zip file
$(extract_dir)/%: $(download_dir)/%.zip | $(extract_dir)
	@mkdir -p "$@"
	-7z x -y -o"$@" "$<" || echo "$@" >> failed.txt

# fetches all zip files and extracts them
fetch: download-list.txt
	@echo ">> downloading and extracting all zip files..."
	-rm failed_curl.txt failed_unzip.txt
	@while read file; do \
	  $(MAKE) "$(extract_dir)/$$file"; \
	done < $<

# re-fetches the zip files that failed to download or extract
re-fetch: failed.txt
	@echo "Re-fetching failed zip files..."
	@while read file; do \
	  rm -rf "$$file"; \
	  $(MAKE) "$$file"; \
	done < $<

# groups the SQLite3 databases by language
$(grouped_dir)/%: $(grouped_dir)
	@echo ">> grouping SQLite3 DBs for language: $* in $<"
	@find $(extract_dir) -type f -name "*.SQLite3" | while read db; do \
	  language=$$(sqlite3 "$$db" "SELECT value FROM info WHERE name = 'language' LIMIT 1;"); \
	  if [ -z "$$language" ]; then \
	    echo "$@" >> failed.txt; \
	  elif [ "$$language" = "$*" ]; then \
	    mkdir -p "$(grouped_dir)/$$language"; \
	    base=$$(basename "$$db"); \
	    safe_name=$$(echo "$$base" | tr "'" "_"); \
	    cp "$$db" "$(grouped_dir)/$$language/$$safe_name"; \
	  fi; \
	done

# merges the SQLite3 databases for each language
$(merged_dir)/%.SQLite3: $(grouped_dir)/% | $(merged_dir)
	@echo ">> merging SQLite3 DBs for language: $* in $<"
	tmp_sql=$$(mktemp); \
	echo 'PRAGMA foreign_keys=OFF;' >> $$tmp_sql; \
	echo 'CREATE TABLE IF NOT EXISTS _sources (source_number NUM, name TEXT, relation TEXT, description_short TEXT, description_long TEXT, origin TEXT, chapter_string TEXT, chapter_string_ps TEXT, PRIMARY KEY (source_number));' >> $$tmp_sql; \
	echo 'CREATE UNIQUE INDEX IF NOT EXISTS idx_sources ON _sources (source_number, name);' >> $$tmp_sql; \
	idx=0; \
	verses_sql=""; \
	dbs=$$(find "$<" -name '*.SQLite3' | sort); \
	main_db=$$(cat main_sources.json | jq -r ".$*"); \
	echo "ATTACH '$$main_db' AS source;" >> $$tmp_sql; \
	echo "CREATE TABLE _books AS SELECT * FROM source.books_all;" >> $$tmp_sql; \
	echo "CREATE INDEX IF NOT EXISTS idx_books_number ON _books (book_number);" >> $$tmp_sql; \
	echo "DETACH source;" >> $$tmp_sql; \
	for db in $$dbs; do \
	  name=$$(basename "$$db" .SQLite3); \
	  dot_count=$$(echo "$$name" | sed 's/[^.]//g' | wc -c | tr -d '[:space:]'); \
	  if [ "$$dot_count" -gt 1 ]; then continue; fi; \
	  echo "ATTACH '$$db' AS source;" >> $$tmp_sql; \
	  table="verses_$$(printf "%02d" $$idx)"; \
	  echo "CREATE TABLE $$table AS SELECT $$idx AS source_number, book_number, chapter, verse, text FROM source.verses;" >> $$tmp_sql; \
	  echo "CREATE INDEX IF NOT EXISTS idx_$$table ON $$table (book_number, chapter, verse);" >> $$tmp_sql; \
	  echo "INSERT INTO _sources SELECT $$idx, '$$name', 'verses'," >> $$tmp_sql; \
	  echo "(SELECT value FROM source.info WHERE name='description')," >> $$tmp_sql; \
	  echo "(SELECT value FROM source.info WHERE name='detailed_info')," >> $$tmp_sql; \
	  echo "(SELECT value FROM source.info WHERE name='origin')," >> $$tmp_sql; \
	  echo "(SELECT value FROM source.info WHERE name='chapter_string')," >> $$tmp_sql; \
	  echo "(SELECT value FROM source.info WHERE name='chapter_string_ps');" >> $$tmp_sql; \
	  echo "DETACH source;" >> $$tmp_sql; \
	  verses_sql="$$verses_sql SELECT * FROM $$table UNION ALL "; \
	  idx=$$((idx+1)); \
	done; \
	verses_sql=$${verses_sql% UNION ALL }; \
	echo "CREATE VIEW _all_verses AS" >> $$tmp_sql; \
	echo "SELECT ('$*/' || v.source_number || '/' || v.book_number || '/' || v.chapter || '/' || v.verse) AS id, '$*' AS language, s.name AS source, (b.short_name || ' ' || v.chapter || ',' || v.verse) AS address, v.*" >> $$tmp_sql; \
	echo "  FROM ($$verses_sql) v" >> $$tmp_sql; \
	echo "  JOIN _sources s ON v.source_number = s.source_number" >> $$tmp_sql; \
	echo "  JOIN _books b ON v.book_number = b.book_number;" >> $$tmp_sql; \
	sqlite3 "$@" < "$$tmp_sql"; \
	rm -f "$$tmp_sql"

upload-%: $(merged_dir)/%.SQLite3
	@echo ">> uploading SQLite3 DB for language: $* to $(output_dir)"
	@python3 scripts/upload.py "$<"

# trains the LoRA model using the merged SQLite3 databases
#train: $(wildcard $(merged_dir)/*.SQLite3) | $(output_dir)
#	@echo ">> launching LoRA training script..."
#	@python3 scripts/train.py "$(model_id)" "$(output_dir)" $(wildcard $(merged_dir)/*.SQLite3)

upload: $(addprefix upload-,$(langs)) apply-helpers
	@echo ">> uploading SQLite3 DBs for languages: $(langs)"

apply-helpers: $(helpers_sql)
	@echo ">> applying helpers"
	@PGPASSWORD=$(POSTGRES_PASSWORD) psql \
	  -h $(POSTGRES_HOST) \
	  -p $(POSTGRES_PORT) \
	  -U $(POSTGRES_USER) \
	  -d $(POSTGRES_DB) \
	  -f $(helpers_sql)

embed:
	python3 scripts/embed.py

$(helpers_sql):
	@echo ">> generating SQL helper functions and materialized views for schemas: $(langs)"
	@echo "-- IMMUTABLE SQL FUNCTIONS" > $@
	@echo "CREATE OR REPLACE FUNCTION public.strip_basic_tags(input text)" >> $@
	@echo "RETURNS text AS \$$\$$" >> $@
	@echo "  SELECT regexp_replace(input, '</?(div|q|Q|x|X|E|g|G|WW|small|t)(\\s[^<>]*)?/?>', '', 'gi');" >> $@
	@echo "\$$\$$ LANGUAGE sql IMMUTABLE;" >> $@
	@echo "" >> $@
	@echo "CREATE OR REPLACE FUNCTION public.sanitize_text(input text)" >> $@
	@echo "RETURNS text AS \$$\$$" >> $@
	@echo "  SELECT regexp_replace(" >> $@
	@echo "           regexp_replace(" >> $@
	@echo "             regexp_replace(" >> $@
	@echo "               regexp_replace(" >> $@
	@echo "                 regexp_replace(" >> $@
	@echo "                   regexp_replace(" >> $@
	@echo "                     regexp_replace(" >> $@
	@echo "                       regexp_replace(" >> $@
	@echo "                         regexp_replace(input," >> $@
	@echo "                           '<(S|m|f|n)(\\s[^<>]*)?>.*?</\\1>', '', 'gi')," >> $@
	@echo "                         '<(S|m|f|n)(\\s[^<>]*)?/?>', '', 'gi')," >> $@
	@echo "                       '</?(J|e|i)(\\s[^<>]*)?/?>', '', 'gi')," >> $@
	@echo "                     '<(br|pb)(\\s[^<>]*)?/?>', '', 'gi')," >> $@
	@echo "                   '<(/)?[a-zA-Z0-9]+[^<>]*>', '', 'g')," >> $@
	@echo "                 '<>', '', 'g')," >> $@
	@echo "               '[<>]+', '', 'g')," >> $@
	@echo "             '\\s+', ' ', 'g')," >> $@
	@echo "           '^\\s+|\\s+$$', '', 'g');" >> $@
	@echo "\$$\$$ LANGUAGE sql IMMUTABLE;" >> $@
	@echo "" >> $@
	@echo "-- MATERIALIZED VIEW: _all_verses" >> $@
	@echo "CREATE MATERIALIZED VIEW public._all_verses AS" >> $@
	@$(foreach lang, $(langs), \
	  printf "SELECT id, language, source, address, source_number, book_number, chapter, verse,\n" >> $@; \
	  printf "       public.strip_basic_tags(text) AS text\n" >> $@; \
	  printf "  FROM $(lang)._all_verses" >> $@; \
	  if [ "$(lang)" != "$(lastword $(langs))" ]; then printf "\nUNION ALL\n" >> $@; fi; \
	)
	@printf "\nWITH NO DATA;\n\n" >> $@
	@echo "-- MATERIALIZED VIEW: _sanitized_verses" >> $@
	@printf "CREATE MATERIALIZED VIEW public._sanitized_verses AS\n" >> $@
	@printf "SELECT id, language, source, address, source_number, book_number, chapter, verse,\n" >> $@
	@printf "       public.sanitize_text(text) AS text\n" >> $@
	@printf "  FROM public._all_verses\n" >> $@
	@printf "WITH NO DATA;\n\n" >> $@
	@echo "-- INDEXES" >> $@
	@echo "CREATE INDEX idx_sanitized_verses_language ON public._sanitized_verses(language);" >> $@
	@echo "CREATE INDEX idx_sanitized_verses_book_chapter_verse ON public._sanitized_verses(book_number, chapter, verse);" >> $@
	@echo "CREATE INDEX idx_sanitized_verses_source_number ON public._sanitized_verses(source_number);" >> $@
	@echo "REFRESH MATERIALIZED VIEW public._all_verses;" >> $@
	@echo "REFRESH MATERIALIZED VIEW public._sanitized_verses;" >> $@
