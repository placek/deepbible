common_mk := build/common.mk
ifeq ($(origin $(common_mk)), undefined)
  $(eval $(common_mk) := included)
  include $(common_mk)
endif

sqls := $(helpers_dir)/01_all_verses.sql \
				$(helpers_dir)/02_books.sql \
				$(helpers_dir)/03_sources.sql \
				$(helpers_dir)/04_commentaries.sql \
				$(helpers_dir)/05_stories.sql \
				$(helpers_dir)/06_dictionary_entries.sql \
				$(helpers_dir)/07_embeddings.sql \
				$(helpers_dir)/11_errata.sql \
				$(helpers_dir)/12_functions.sql \
				$(helpers_dir)/13_postgrest.sql

.PHONY: clean-helpers apply-helpers

clean-helpers:
	@$(call say,cleaning helpers directory)
	-rm -rf $(helpers_dir)

# creates necessary directories
$(helpers_dir):
	@$(call say,ensuring helpers directory $@ exists)
	@mkdir -p $@

# copies the sql files from sql_dir to helpers_dir (only *.sql)
$(helpers_dir)/%.sql: $(sql_dir)/%.sql | $(helpers_dir)
	@$(call say,copying $(notdir $<) into $(helpers_dir))
	@cp $< $@

# generates the all_verses.sql file with materialized view for all languages
$(helpers_dir)/01_all_verses.sql: $(helpers_dir)
	@$(call say,generating deepbible._all_verses helper SQL)
	@echo "-- all verses for deepbible schema" > "$@"
	@echo "CREATE SCHEMA IF NOT EXISTS deepbible;" >> "$@"
	@echo "DROP MATERIALIZED VIEW IF EXISTS deepbible._all_verses;" >> "$@"
	@echo "CREATE MATERIALIZED VIEW deepbible._all_verses AS" >> "$@"
	@$(foreach lang,$(langs), \
		printf "SELECT id, language, source, book, book_name, address,\n" >> "$@"; \
		printf "       source_number, book_number, chapter, verse, text\n" >> "$@"; \
		printf "FROM $(lang)._all_verses" >> "$@"; \
		if [ "$(lang)" != "$(lastword $(langs))" ]; then printf "\nUNION ALL\n" >> "$@"; else printf "\n" >> "$@"; fi; \
	)
	@echo ";" >> "$@"
	@echo >> "$@"

# generates the books.sql file with view for all languages
$(helpers_dir)/02_books.sql: $(helpers_dir)
	@$(call say,generating deepbible._all_books helper SQL)
	@echo "-- all books for deepbible schema" > "$@"
	@echo "CREATE SCHEMA IF NOT EXISTS deepbible;" >> "$@"
	@echo "CREATE OR REPLACE VIEW deepbible._all_books AS" >> "$@"
	@$(foreach lang,$(langs), \
		printf "SELECT * FROM $(lang)._books" >> "$@"; \
		if [ "$(lang)" != "$(lastword $(langs))" ]; then printf "\nUNION ALL\n" >> "$@"; fi; \
	)
	@echo >> "$@"
	@echo "ORDER BY language, book_number;" >> "$@"
	@echo >> "$@"

# generates the sources.sql file with view for all languages
$(helpers_dir)/03_sources.sql: $(helpers_dir)
	@$(call say,generating deepbible._all_sources helper SQL)
	@echo "-- all sources for deepbible schema" > "$@"
	@echo "CREATE SCHEMA IF NOT EXISTS deepbible;" >> "$@"
	@echo "CREATE OR REPLACE VIEW deepbible._all_sources AS" >> "$@"
	@$(foreach lang,$(langs), \
		printf "SELECT * FROM $(lang)._sources" >> "$@"; \
		if [ "$(lang)" != "$(lastword $(langs))" ]; then printf "\nUNION ALL\n" >> "$@"; fi; \
	)
	@echo >> "$@"
	@echo "ORDER BY id;" >> "$@"
	@echo >> "$@"

# generates the commentaries.sql file with view for all languages
$(helpers_dir)/04_commentaries.sql: $(helpers_dir)
	@$(call say,generating deepbible._all_commentaries helper SQL)
	@echo "-- all commentaries for deepbible schema" > "$@"
	@echo "CREATE SCHEMA IF NOT EXISTS deepbible;" >> "$@"
	@echo "CREATE OR REPLACE VIEW deepbible._all_commentaries AS" >> "$@"
	@$(foreach lang,$(langs), \
		printf "SELECT * FROM $(lang)._commentaries" >> "$@"; \
		if [ "$(lang)" != "$(lastword $(langs))" ]; then printf "\nUNION ALL\n" >> "$@"; fi; \
	)
	@echo ";" >> "$@"
	@echo >> "$@"

# generates the stories.sql file with view for all languages
$(helpers_dir)/05_stories.sql: $(helpers_dir)
	@$(call say,generating deepbible._all_stories helper SQL)
	@echo "-- all stories for deepbible schema" > "$@"
	@echo "CREATE SCHEMA IF NOT EXISTS deepbible;" >> "$@"
	@echo "CREATE OR REPLACE VIEW deepbible._all_stories AS" >> "$@"
	@$(foreach lang,$(langs), \
	  printf "SELECT * FROM $(lang)._stories" >> "$@"; \
	  if [ "$(lang)" != "$(lastword $(langs))" ]; then printf "\nUNION ALL\n" >> "$@"; fi; \
	)
	@echo >> "$@"
	@echo "ORDER BY language, source_number, book_number, chapter, verse;" >> "$@"
	@echo >> "$@"

# generates the dictionary_entries.sql file with view for all languages
$(helpers_dir)/06_dictionary_entries.sql: $(helpers_dir)
	@$(call say,generating deepbible._all_dictionary_entries helper SQL)
	@echo "-- all dictionary entries for deepbible schema" > "$@"
	@echo "CREATE SCHEMA IF NOT EXISTS deepbible;" >> "$@"
	@echo "CREATE OR REPLACE VIEW deepbible._all_dictionary_entries AS" >> "$@"
	@$(foreach lang,$(langs), \
	  printf "SELECT * FROM $(lang)._dictionary_entries" >> "$@"; \
	  if [ "$(lang)" != "$(lastword $(langs))" ]; then printf "\nUNION ALL\n" >> "$@"; fi; \
	)
	@echo >> "$@"
	@echo "ORDER BY language, source_number;" >> "$@"
	@echo >> "$@"

# generates the embeddings.sql file with table for verse embeddings
$(helpers_dir)/07_embeddings.sql: $(helpers_dir)
	@$(call say,generating deepbible._embeddings helper SQL)
	@echo "-- embeddings table for deepbible schema" > "$@"
	@echo "CREATE SCHEMA IF NOT EXISTS deepbible;" >> "$@"
	@echo "CREATE EXTENSION IF NOT EXISTS vector;" >> "$@"
	@echo "CREATE EXTENSION IF NOT EXISTS http;" >> "$@"
	@echo "CREATE TABLE IF NOT EXISTS deepbible._embeddings(" >> "$@"
	@echo "  id text COLLATE pg_catalog.\"default\" NOT NULL," >> "$@"
	@echo "  embedding vector(1024)," >> "$@"
	@echo "  CONSTRAINT _embeddings_pkey PRIMARY KEY (id)" >> "$@"
	@echo ");" >> "$@"
	@echo >> "$@"

# combine helpers pieces
$(helpers_dir)/_helpers.sql: $(sqls) | $(helpers_dir)
	@$(call say,combining helper SQL pieces)
	@cat $^ > "$@"

# apply (define helpers_sql if you use it)
helpers_sql := $(helpers_dir)/_helpers.sql

apply-helpers: $(helpers_sql)
	@$(call say,applying helpers)
	@psql "$(DATABASE_URL)" -v ON_ERROR_STOP=1 -f "$(helpers_sql)"

.PHONY: embed-source

embed-source:
	@if [ -z "$(SOURCE)" ]; then \
		printf 'SOURCE is required. Example: make embed-source SOURCE=BT_03\n'; \
		exit 1; \
	fi
	@$(call say,embedding verses for source $(SOURCE))
	@psql "$(DATABASE_URL)" -v ON_ERROR_STOP=1 -c "INSERT INTO deepbible._embeddings (id, embedding) SELECT v.id, deepbible.generate_embedding(v.text) FROM deepbible._all_verses v WHERE v.source = '$(SOURCE)' ON CONFLICT (id) DO NOTHING;"
