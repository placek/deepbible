common_mk := build/common.mk
ifeq ($(origin $(common_mk)), undefined)
  $(eval $(common_mk) := included)
  include $(common_mk)
endif

.PHONY: upload-% upload

upload_tables ?= _sources _books _all_verses _stories _commentaries

upload-cross-references: $(cross_refs_db)
	@echo ">> uploading cross-references"
	SQLITE_PATH="$$(realpath $<)"; \
	PGURL="$(DATABASE_URL)"; \
	TABLES="'_cross_references'"; \
	SCHEMA="public"; \
	sed "s#{{SQLITE_PATH}}#$$SQLITE_PATH#g; s#{{PGURL}}#$$PGURL#g; s#{{SCHEMA}}#$$SCHEMA#g; s#{{TABLES}}#$$TABLES#g" upload.load > /tmp/pgloader.$*.load; \
	pgloader /tmp/pgloader.$*.load

# uploads the merged SQLite3 database to the PostgreSQL database
upload-%: $(merged_dir)/%.SQLite3 upload-cross-references
	@echo ">> uploading SQLite3 DB for language: $* (tables: $(upload_tables)) using $(DATABASE_URL)"
	@SCHEMA="$*"; \
	SQLITE_PATH="$$(realpath "$<")"; \
	PGURL="$(DATABASE_URL)"; \
	TABLES="$$(printf "'%s', " $(upload_tables))"; \
	TABLES="$${TABLES%, }"; \
	sed "s#{{SQLITE_PATH}}#$$SQLITE_PATH#g; s#{{PGURL}}#$$PGURL#g; s#{{SCHEMA}}#$$SCHEMA#g; s#{{TABLES}}#$$TABLES#g" upload.load > /tmp/pgloader.$*.load; \
	pgloader /tmp/pgloader.$*.load

# uploads the SQLite3 databases for all languages
upload: $(addprefix upload-,$(langs))
	@echo ">> uploading SQLite3 DBs for languages: $(langs) (tables: $(upload_tables))"
