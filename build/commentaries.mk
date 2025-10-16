common_mk := build/common.mk
ifeq ($(origin $(common_mk)), undefined)
  $(eval $(common_mk) := included)
  include $(common_mk)
endif

.PHONY: clean-commentaries

clean-commentaries:
	-rm -rf $(commentaries_dir)

# creates necessary directories
$(commentaries_dir):
	@mkdir -p $@

# move commentary databases to the commentaries directory from the grouped_dir under the subdirectory named by language
$(commentaries_dir)/%: $(grouped_dir)/% | $(commentaries_dir)
	@echo ">> moving commentary DBs for language: $* in $@"
	@mkdir -p "$@"
	@find $(grouped_dir)/$* -type f -name "*.commentaries.SQLite3" | while read db; do \
	  language=$$(sqlite3 "$$db" "SELECT value FROM info WHERE name = 'language' LIMIT 1;"); \
	  if [ -z "$$language" ]; then \
	    echo "$$db" >> failed.txt; \
	  elif [ "$$language" = "$*" ]; then \
	    base=$$(basename "$$db"); \
	    safe_name=$$(echo "$$base" | tr "'" "_"); \
	    mv "$$db" "$@/$$safe_name"; \
	  fi; \
	done
