common_mk := build/common.mk
ifeq ($(origin $(common_mk)), undefined)
  $(eval $(common_mk) := included)
  include $(common_mk)
endif

.PHONY: cross-references clean-cross-references

clean-cross-references:
	-rm -rf $(cross_refs_dir)

# creates necessary directories
$(cross_refs_dir):
	@mkdir -p $@

# downloads and extracts the cross references file
$(cross_refs_zip): | $(cross_refs_dir)
	curl -fL -o "$@" "$(cross_refs_url)"

# extracts the cross references text file
$(cross_refs_txt): $(cross_refs_zip)
	-7z x -y -o"$(subst .zip,,$<)" "$<"
	mv "$(subst .zip,,$<)/cross_references.txt" "$@"
	sed -i.bak '1d' "$@"

# converts the cross references text file to SQL
$(cross_refs_sql): $(cross_refs_txt)
	@echo ">> generating SQL for cross references..."
	@echo "BEGIN TRANSACTION;" > "$@"
	@echo "CREATE TABLE IF NOT EXISTS cr (vfrom TEXT, vto TEXT, votes TEXT);" >> "$@"
	@echo ".mode tabs" >> "$@"
	@echo ".import '$(cross_refs_txt)' cr" >> "$@"
	@echo "CREATE VIEW cr_split AS" >> "$@"
	@echo "SELECT" >> "$@"
	@echo "  trim(json_extract(fs, '\$$[0]')) AS b," >> "$@"
	@echo "  trim(json_extract(fs, '\$$[1]')) AS c," >> "$@"
	@echo "  trim(json_extract(fs, '\$$[2]')) AS v," >> "$@"
	@echo "  trim(json_extract(ts, '\$$[0]')) AS b1," >> "$@"
	@echo "  trim(json_extract(ts, '\$$[1]')) AS c1," >> "$@"
	@echo "  trim(json_extract(ts, '\$$[2]')) AS v1," >> "$@"
	@echo "  trim(json_extract(te, '\$$[0]')) AS b2," >> "$@"
	@echo "  trim(json_extract(te, '\$$[1]')) AS c2," >> "$@"
	@echo "  trim(json_extract(te, '\$$[2]')) AS v2," >> "$@"
	@echo "  r AS rate" >> "$@"
	@echo "FROM (" >> "$@"
	@echo "  SELECT" >> "$@"
	@echo "    ('[\"' || replace(f, '.', '\",\"') || '\"]') AS fs," >> "$@"
	@echo "    ('[\"' || replace(trim(json_extract(t, '\$$[0]')), '.', '\",\"') || '\"]') AS ts," >> "$@"
	@echo "    ('[\"' || replace(ifnull(trim(json_extract(t, '\$$[1]')), ''), '.', '\",\"') || '\"]') AS te," >> "$@"
	@echo "    v AS r" >> "$@"
	@echo "  FROM (" >> "$@"
	@echo "    SELECT" >> "$@"
	@echo "      vfrom AS f," >> "$@"
	@echo "      ('[\"' || replace(vto, '-', '\",\"') || '\"]') AS t," >> "$@"
	@echo "      votes AS v" >> "$@"
	@echo "    FROM cr" >> "$@"
	@echo "  )" >> "$@"
	@echo ");" >> "$@"
	@echo "CREATE TABLE cross_references (book_number INTEGER, chapter INTEGER, verse INTEGER, b1 INTEGER, c1 INTEGER, v1 INTEGER, b2 INTEGER, c2 INTEGER, v2 INTEGER, rate INTEGER);" >> "$@"
	@echo "COMMIT;" >> "$@"
	@echo "BEGIN;" >> "$@"
	@echo "ATTACH DATABASE '$(books_db)' AS booksdb;" >> "$@"
	@echo "INSERT INTO cross_references" >> "$@"
	@echo "SELECT" >> "$@"
	@echo "  bf.number AS book_number," >> "$@"
	@echo "  CASE WHEN length(trim(cs.c))>0 AND (trim(cs.c) GLOB '[0-9]*' OR trim(cs.c) GLOB '-[0-9]*')" >> "$@"
	@echo "       THEN CAST(trim(cs.c) AS INTEGER) ELSE NULL END AS chapter," >> "$@"
	@echo "  CASE WHEN length(trim(cs.v))>0 AND (trim(cs.v) GLOB '[0-9]*' OR trim(cs.v) GLOB '-[0-9]*')" >> "$@"
	@echo "       THEN CAST(trim(cs.v) AS INTEGER) ELSE NULL END AS verse," >> "$@"
	@echo "  bt1.number AS b1," >> "$@"
	@echo "  CASE WHEN length(trim(cs.c1))>0 AND (trim(cs.c1) GLOB '[0-9]*' OR trim(cs.c1) GLOB '-[0-9]*')" >> "$@"
	@echo "       THEN CAST(trim(cs.c1) AS INTEGER) ELSE NULL END AS c1," >> "$@"
	@echo "  CASE WHEN length(trim(cs.v1))>0 AND (trim(cs.v1) GLOB '[0-9]*' OR trim(cs.v1) GLOB '-[0-9]*')" >> "$@"
	@echo "       THEN CAST(trim(cs.v1) AS INTEGER) ELSE NULL END AS v1," >> "$@"
	@echo "  bt2.number AS b2," >> "$@"
	@echo "  CASE WHEN length(trim(cs.c2))>0 AND (trim(cs.c2) GLOB '[0-9]*' OR trim(cs.c2) GLOB '-[0-9]*')" >> "$@"
	@echo "       THEN CAST(trim(cs.c2) AS INTEGER) ELSE NULL END AS c2," >> "$@"
	@echo "  CASE WHEN length(trim(cs.v2))>0 AND (trim(cs.v2) GLOB '[0-9]*' OR trim(cs.v2) GLOB '-[0-9]*')" >> "$@"
	@echo "       THEN CAST(trim(cs.v2) AS INTEGER) ELSE NULL END AS v2," >> "$@"
	@echo "  CASE WHEN length(trim(cs.rate))>0 AND (trim(cs.rate) GLOB '[0-9]*' OR trim(cs.rate) GLOB '-[0-9]*')" >> "$@"
	@echo "       THEN CAST(trim(cs.rate) AS INTEGER) ELSE NULL END AS rate" >> "$@"
	@echo "FROM cr_split cs" >> "$@"
	@echo "LEFT JOIN booksdb.books bf  ON lower(bf.name)  = lower(cs.b)" >> "$@"
	@echo "LEFT JOIN booksdb.books bt1 ON lower(bt1.name) = lower(cs.b1)" >> "$@"
	@echo "LEFT JOIN booksdb.books bt2 ON lower(bt2.name) = lower(cs.b2);" >> "$@"
	@echo "COMMIT;" >> "$@"

# creates the cross references SQLite3 database
$(cross_refs_db): $(cross_refs_sql)
	@echo ">> creating cross references SQLite3 database..."
	sqlite3 "$@" < "$<"
