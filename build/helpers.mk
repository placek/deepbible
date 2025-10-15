common_mk := build/common.mk
ifeq ($(origin $(common_mk)), undefined)
  $(eval $(common_mk) := included)
  include $(common_mk)
endif

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
$(helpers_dir)/all_verses.sql: $(helpers_dir)
	@echo "-- all verses for public schema" > "$@"
	@echo "DROP MATERIALIZED VIEW IF EXISTS public._all_verses;" >> "$@"
	@echo "CREATE MATERIALIZED VIEW public._all_verses AS" >> "$@"
	@$(foreach lang,$(langs), \
		printf "SELECT * FROM $(lang)._all_verses" >> "$@"; \
		if [ "$(lang)" != "$(lastword $(langs))" ]; then printf "\nUNION ALL\n" >> "$@"; fi; \
	)
	@echo ";" >> "$@"
	@echo >> "$@"

# generates the books.sql file with view for all languages
$(helpers_dir)/books.sql: $(helpers_dir)
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
$(helpers_dir)/sources.sql: $(helpers_dir)
	@echo "-- all sources for public schema" > "$@"
	@echo "CREATE OR REPLACE VIEW public._all_sources AS" >> "$@"
	@$(foreach lang,$(langs), \
		printf "SELECT * FROM $(lang)._sources" >> "$@"; \
		if [ "$(lang)" != "$(lastword $(langs))" ]; then printf "\nUNION ALL\n" >> "$@"; fi; \
	)
	@echo >> "$@"
	@echo "ORDER BY id;" >> "$@"
	@echo >> "$@"

# combine helpers pieces
$(helpers_dir)/_helpers.sql: $(helpers_dir)/all_verses.sql $(helpers_dir)/books.sql $(helpers_dir)/sources.sql $(helpers_dir)/errata.sql $(helpers_dir)/functions.sql $(helpers_dir)/postgrest.sql $(helpers_dir)/cross_references.sql
	@cat $^ > "$@"

# apply (define helpers_sql if you use it)
helpers_sql := $(helpers_dir)/_helpers.sql

apply-helpers: $(helpers_sql)
	@echo ">> applying helpers"
	@psql "$(DATABASE_URL)" -v ON_ERROR_STOP=1 -f "$(helpers_sql)"
