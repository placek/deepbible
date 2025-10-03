common_mk := build/common.mk
ifeq ($(origin $(common_mk)), undefined)
  $(eval $(common_mk) := included)
  include $(common_mk)
endif

.PHONY: upload-% upload

# uploads the merged SQLite3 database to the PostgreSQL database
upload-%: $(merged_dir)/%.SQLite3
	@echo ">> uploading SQLite3 DB for language: $* using $(DATABASE_URL)"
	@SCHEMA="$*"; \
	SQLITE_PATH="$$(realpath "$<")"; \
	PGURL="$(DATABASE_URL)"; \
	sed "s#{{SQLITE_PATH}}#$$SQLITE_PATH#g; s#{{PGURL}}#$$PGURL#g; s#{{SCHEMA}}#$$SCHEMA#g" upload.load > /tmp/pgloader.$*.load; \
	pgloader /tmp/pgloader.$*.load

# uploads the SQLite3 databases for all languages
upload: $(addprefix upload-,$(langs))
	@echo ">> uploading SQLite3 DBs for languages: $(langs)"
