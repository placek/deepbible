common_mk := build/common.mk
ifeq ($(origin $(common_mk)), undefined)
  $(eval $(common_mk) := included)
  include $(common_mk)
endif

typst_dir := data/typst

# Parameters:
#   ADDRESS  - bible address (e.g. "J 3,16-17") or book short name (e.g. "J")
#   SOURCE   - translation source (e.g. "NA28")
#   TEMPLATE - path to a .typ template file
#
# The template receives the data as a JSON file via --input data=<path>.
# JSON structure:
#   {
#     "source": "NA28",
#     "book": "J",
#     "book_name": "John",
#     "address": "J 3,16-17",
#     "chapters": {
#       "1": [{"verse": 1, "text": "..."}, ...],
#       "3": [{"verse": 16, "text": "..."}, ...]
#     }
#   }
#
# Usage:
#   make render-typst ADDRESS="J 3,16-17" SOURCE="NA28" TEMPLATE="templates/book.typ"
#   make render-typst ADDRESS="J" SOURCE="NA28" TEMPLATE="templates/book.typ"

.PHONY: render-typst clean-typst

clean-typst:
	@$(call say,cleaning typst artifacts)
	-rm -rf $(typst_dir)

$(typst_dir):
	@mkdir -p $@

render-typst: | $(typst_dir)
ifndef ADDRESS
	$(error ADDRESS is required – e.g. ADDRESS="J 3,16-17" or ADDRESS="J")
endif
ifndef SOURCE
	$(error SOURCE is required – e.g. SOURCE="NA28")
endif
ifndef TEMPLATE
	$(error TEMPLATE is required – e.g. TEMPLATE="templates/book.typ")
endif
	@slug=$$(echo "$(ADDRESS)_$(SOURCE)" | tr ' ,:.' '_'); \
	json="$$(pwd)/$(typst_dir)/$$slug.json"; \
	pdf="$$(pwd)/$(typst_dir)/$$slug.pdf"; \
	db=""; \
	for f in $(merged_dir)/*.SQLite3; do \
	  found=$$(sqlite3 "$$f" \
	    "SELECT 1 FROM _all_verses WHERE source='$(SOURCE)' LIMIT 1" 2>/dev/null); \
	  if [ "$$found" = "1" ]; then db="$$f"; break; fi; \
	done; \
	if [ -z "$$db" ]; then \
	  echo "error: source '$(SOURCE)' not found in any merged database"; \
	  exit 1; \
	fi; \
	printf '$(ansi_bold_green)%s$(ansi_reset)\n' "source $(SOURCE) found in $$db"; \
	book=$$(echo '$(ADDRESS)' | sed 's/\s*[0-9].*//'); \
	addr='$(ADDRESS)'; \
	case "$$addr" in \
	  *,*) \
	    chapter=$$(echo "$$addr" | sed 's/^.*\s\+\([0-9]\+\),.*/\1/'); \
	    verses_part=$$(echo "$$addr" | sed 's/^.*,//'); \
	    where="source='$(SOURCE)' AND book='$$book' AND chapter=$$chapter"; \
	    clause=""; \
	    IFS='.'; set -- $$verses_part; unset IFS; \
	    verse_list=""; \
	    for part do \
	      case "$$part" in \
	        *-*) \
	          vstart=$$(echo "$$part" | cut -d- -f1); \
	          vend=$$(echo "$$part" | cut -d- -f2); \
	          if [ -z "$$vend" ]; then \
	            clause="$$clause OR verse>=$$vstart"; \
	          else \
	            clause="$$clause OR (verse>=$$vstart AND verse<=$$vend)"; \
	          fi ;; \
	        *) \
	          clause="$$clause OR verse=$$part" ;; \
	      esac; \
	    done; \
	    clause=$$(echo "$$clause" | sed 's/^ OR //'); \
	    where="$$where AND ($$clause)"; \
	    ;; \
	  *[0-9]*) \
	    chapter=$$(echo "$$addr" | sed 's/^.*\s\+//'); \
	    where="source='$(SOURCE)' AND book='$$book' AND chapter=$$chapter"; \
	    ;; \
	  *) \
	    where="source='$(SOURCE)' AND book='$$book'"; \
	    ;; \
	esac; \
	printf '$(ansi_bold_green)%s$(ansi_reset)\n' "querying: $$where"; \
	sqlite3 -json "$$db" \
	  "SELECT book, book_name, chapter, verse, text \
	   FROM _all_verses WHERE $$where ORDER BY chapter, verse" \
	  > "$$json.raw"; \
	if [ ! -s "$$json.raw" ]; then \
	  echo "error: no verses found for ADDRESS='$(ADDRESS)' SOURCE='$(SOURCE)'"; \
	  rm -f "$$json.raw"; \
	  exit 1; \
	fi; \
	jq -n --arg source '$(SOURCE)' --arg address '$(ADDRESS)' --slurpfile rows "$$json.raw" '{source: $$source, book: $$rows[0][0].book, book_name: $$rows[0][0].book_name, address: $$address, chapters: ($$rows[0] | group_by(.chapter) | map({(.[0].chapter | tostring): [.[] | {verse, text}]}) | add)}' > "$$json"; \
	rm -f "$$json.raw"; \
	printf '$(ansi_bold_green)%s$(ansi_reset)\n' "rendering $$pdf"; \
	typst compile "$$(pwd)/$(TEMPLATE)" "$$pdf" --root "/" --input "data=$$json"; \
	printf '$(ansi_bold_green)%s$(ansi_reset)\n' "done: $$pdf"
