common_mk := build/common.mk
ifeq ($(origin $(common_mk)), undefined)
  $(eval $(common_mk) := included)
  include $(common_mk)
endif

.PRECIOUS: $(download_dir)/%.zip $(extract_dir)/% $(grouped_dir)/%
.PHONY: clean-download fetch re-fetch

clean-download:
	-rm -rf download-list.txt failed.txt failed_curl.txt failed_unzip.txt

# creates necessary directories
$(download_dir) $(extract_dir) $(grouped_dir):
	@mkdir -p $@

# fetches the list of available zip files
download-list.txt:
	curl -s "$(bible_sources_url)/b4_index.php" | \
	grep -oP 'href="_dl.php[^"]+"' | \
	sed 's/.*a=\([^&]\+\)&.*/\1/' | \
	sort > $@

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
