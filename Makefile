bible_sources_url := https://www.ph4.org

download_dir := data/downloads
extract_dir  := data/extracted
grouped_dir  := data/grouped
merged_dir   := data/merged
output_dir   := data/lamb3

model_id     ?= NousResearch/Llama-2-7b-hf
final_jsonl  := $(output_dir)/bible.jsonl
gguf_path    := $(output_dir)/gguf

all:
	@echo "…"

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
	echo "ATTACH 'data/extracted/VULG/VULG.SQLite3' AS source;" >> $$tmp_sql; \
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
	echo "CREATE VIEW _all_verses AS SELECT v.*, s.name AS source, (b.short_name || ' ' || v.chapter || ',' || v.verse) AS address FROM ($$verses_sql) v JOIN _sources s ON v.source_number = s.source_number JOIN _books b ON v.book_number = b.book_number;" >> $$tmp_sql; \
	sqlite3 "$@" < "$$tmp_sql"; \
	rm -f "$$tmp_sql"

# trains the LoRA model using the merged SQLite3 databases
#train: $(wildcard $(merged_dir)/*.SQLite3) | $(output_dir)
#	@echo ">> launching LoRA training script..."
#	@python3 train.py "$(model_id)" "$(output_dir)" $(wildcard $(merged_dir)/*.SQLite3)

clean:
	-rm -rf $(merged_dir) download-list.txt failed.txt

.PRECIOUS: $(download_dir)/%.zip $(extract_dir)/% $(grouped_dir)/% $(merged_dir)/%.SQLite3
.PHONY: fetch re-fetch clean # train
