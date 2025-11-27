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
				$(helpers_dir)/11_errata.sql \
				$(helpers_dir)/12_functions.sql \
				$(helpers_dir)/13_postgrest.sql

.PHONY: clean-helpers apply-helpers

clean-helpers:
	-rm -rf $(helpers_dir)

# creates necessary directories
$(helpers_dir):
	@mkdir -p $@

# copies the sql files from sql_dir to helpers_dir (only *.sql)
$(helpers_dir)/%.sql: $(sql_dir)/%.sql | $(helpers_dir)
	@cp $< $@

# generates the all_verses.sql file with materialized view for all languages
$(helpers_dir)/01_all_verses.sql: $(helpers_dir)
	@echo "-- all verses for public schema" > "$@"
	@echo "DROP INDEX IF EXISTS public.idx__all_verses_text_search;" >> "$@"
	@echo "DROP MATERIALIZED VIEW IF EXISTS public._all_verses;" >> "$@"
	@echo "CREATE MATERIALIZED VIEW public._all_verses AS" >> "$@"
	@$(foreach lang,$(langs), \
		printf "SELECT id, language, source, book, book_name, address,\n" >> "$@"; \
		printf "       source_number, book_number, chapter, verse, text,\n" >> "$@"; \
		printf "       to_tsvector('simple', COALESCE(text, '')) AS text_search\n" >> "$@"; \
		printf "FROM $(lang)._all_verses" >> "$@"; \
		if [ "$(lang)" != "$(lastword $(langs))" ]; then printf "\nUNION ALL\n" >> "$@"; else printf "\n" >> "$@"; fi; \
	)
	@echo ";" >> "$@"
	@echo "CREATE INDEX idx__all_verses_text_search ON public._all_verses USING GIN (text_search);" >> "$@"
	@echo >> "$@"

# generates the books.sql file with view for all languages
$(helpers_dir)/02_books.sql: $(helpers_dir)
	@echo "-- all books for public schema" > "$@"
	@echo "CREATE OR REPLACE VIEW public._all_books AS" >> "$@"
	@$(foreach lang,$(langs), \
		printf "SELECT * FROM $(lang)._books" >> "$@"; \
		if [ "$(lang)" != "$(lastword $(langs))" ]; then printf "\nUNION ALL\n" >> "$@"; fi; \
	)
	@echo >> "$@"
	@echo "ORDER BY language, book_number;" >> "$@"
	@echo >> "$@"

# generates the sources.sql file with view for all languages
$(helpers_dir)/03_sources.sql: $(helpers_dir)
	@echo "-- all sources for public schema" > "$@"
	@echo "CREATE OR REPLACE VIEW public._all_sources AS" >> "$@"
	@$(foreach lang,$(langs), \
		printf "SELECT * FROM $(lang)._sources" >> "$@"; \
		if [ "$(lang)" != "$(lastword $(langs))" ]; then printf "\nUNION ALL\n" >> "$@"; fi; \
	)
	@echo >> "$@"
	@echo "ORDER BY id;" >> "$@"
	@echo >> "$@"

# generates the commentaries.sql file with view for all languages
$(helpers_dir)/04_commentaries.sql: $(helpers_dir)
	@echo "-- all commentaries for public schema" > "$@"
	@echo "CREATE OR REPLACE VIEW public._all_commentaries AS" >> "$@"
	@$(foreach lang,$(langs), \
		printf "SELECT * FROM $(lang)._commentaries" >> "$@"; \
		if [ "$(lang)" != "$(lastword $(langs))" ]; then printf "\nUNION ALL\n" >> "$@"; fi; \
	)
	@echo ";" >> "$@"
	@echo >> "$@"

# generates the stories.sql file with view for all languages
$(helpers_dir)/05_stories.sql: $(helpers_dir)
	@echo "-- all stories for public schema" > "$@"
	@echo "CREATE OR REPLACE VIEW public._all_stories AS" >> "$@"
	@$(foreach lang,$(langs), \
	  printf "SELECT * FROM $(lang)._stories" >> "$@"; \
	  if [ "$(lang)" != "$(lastword $(langs))" ]; then printf "\nUNION ALL\n" >> "$@"; fi; \
	)
	@echo >> "$@"
	@echo "ORDER BY language, source_number, book_number, chapter, verse;" >> "$@"
	@echo >> "$@"

# combine helpers pieces
$(helpers_dir)/_helpers.sql: $(sqls) | $(helpers_dir)
	@cat $^ > "$@"

# apply (define helpers_sql if you use it)
helpers_sql := $(helpers_dir)/_helpers.sql

apply-helpers: $(helpers_sql)
	@echo ">> applying helpers"
	@psql "$(DATABASE_URL)" -v ON_ERROR_STOP=1 -f "$(helpers_sql)"
