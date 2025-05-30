bible_sources_url := https://www.ph4.org

download_dir      := data/downloads
extract_dir       := data/extracted
grouped_dir       := data/grouped
merged_dir        := data/merged
helpers_sql       := helpers.sql

langs             ?= pl la grc

.PRECIOUS: $(download_dir)/%.zip $(extract_dir)/% $(grouped_dir)/% $(merged_dir)/%.SQLite3
.PHONY: all clean fetch re-fetch upload-% upload apply-helpers embed

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
	@echo ">> re-fetching failed zip files..."
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

# uploads the merged SQLite3 database to the PostgreSQL database
upload-%: $(merged_dir)/%.SQLite3
	@echo ">> uploading SQLite3 DB for language: $* to $(output_dir)"
	@python3 scripts/upload.py "$<"

# generates the helpers.sql file with materialized views and functions for all languages
$(helpers_sql): helpers.sql.tpl
	@echo ">> generating helpers.sql with materialized views for: $(langs)"
	@cp helpers.sql.tpl $@.tmp
	@echo "CREATE MATERIALIZED VIEW public._all_verses AS" > all_verses.sql
	@$(foreach lang, $(langs), \
	  printf "SELECT id, language, source, address, source_number, book_number, chapter, verse, text\n  FROM $(lang)._all_verses" >> all_verses.sql; \
	  if [ "$(lang)" != "$(lastword $(langs))" ]; then printf "\nUNION ALL" >> all_verses.sql; fi; \
	  printf "\n" >> all_verses.sql; \
	)
	@echo "WITH NO DATA;" >> all_verses.sql
	@sed -e '/<ALL_VERSES>/ {' -e 'r all_verses.sql' -e 'd' -e '}' $@.tmp > $@
	@echo >> $@
	@cat errata.sql >> $@
	@echo >> $@
	@echo '-- REFRESH VIEWS' >> $@
	@echo 'REFRESH MATERIALIZED VIEW public._all_verses;' >> $@
	@echo 'REFRESH MATERIALIZED VIEW public._raw_verses;' >> $@
	@rm $@.tmp all_verses.sql

# applies the helpers.sql file to the PostgreSQL database
apply-helpers: $(helpers_sql)
	@echo ">> applying helpers"
	@PGPASSWORD=$(POSTGRES_PASSWORD) psql \
	  -h $(POSTGRES_HOST) \
	  -p $(POSTGRES_PORT) \
	  -U $(POSTGRES_USER) \
	  -d $(POSTGRES_DB) \
	  -f $(helpers_sql)

# uploads the SQLite3 databases for all languages
upload: $(addprefix upload-,$(langs)) apply-helpers
	@echo ">> uploading SQLite3 DBs for languages: $(langs)"

# generates the embeddings for all languages
embed:
	python3 scripts/embed.py
