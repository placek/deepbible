bible_sources_url := https://www.ph4.org

download_dir      := data/downloads
extract_dir       := data/extracted
grouped_dir       := data/grouped
merged_dir        := data/merged

helpers_dir       := helpers
sql_dir           := sql

langs             ?= pl la grc en it es fr de

cross_refs_url := https://a.openbible.info/data/cross-references.zip
cross_refs_dir := data/openbible
cross_refs_zip := $(cross_refs_dir)/cross_references.zip
cross_refs_txt := $(cross_refs_dir)/cross_references.txt
cross_refs_sql := $(cross_refs_dir)/cross_references.sql
cross_refs_db := $(cross_refs_dir)/cross_references.SQLite3
books_db := data/cross_references_books.SQLite3
