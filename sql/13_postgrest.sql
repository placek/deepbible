CREATE SCHEMA IF NOT EXISTS deepbible;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'web_anon') THEN
    CREATE ROLE web_anon NOLOGIN;
  END IF;
END
$$;
--CREATE ROLE authenticator NOINHERIT LOGIN PASSWORD 'authpass';
--GRANT web_anon TO authenticator;

GRANT USAGE ON SCHEMA deepbible TO web_anon;
GRANT SELECT ON deepbible._all_sources TO web_anon;
GRANT SELECT ON deepbible._all_books TO web_anon;
GRANT SELECT ON deepbible._all_verses TO web_anon;
GRANT SELECT ON deepbible._all_commentaries TO web_anon;
GRANT SELECT ON deepbible._all_dictionary_entries TO web_anon;
GRANT SELECT ON deepbible._cross_references TO web_anon;
GRANT SELECT ON deepbible._rendered_stories TO web_anon;
GRANT EXECUTE ON FUNCTION deepbible.fetch_commentaries(text) TO web_anon;
GRANT EXECUTE ON FUNCTION deepbible.fetch_cross_references(text) TO web_anon;
GRANT EXECUTE ON FUNCTION deepbible.fetch_rendered_stories(text, text) TO web_anon;
GRANT EXECUTE ON FUNCTION deepbible.fetch_verse_with_metadata(text) TO web_anon;
GRANT EXECUTE ON FUNCTION deepbible.fetch_verses_by_address(text, text, boolean) TO web_anon;
GRANT EXECUTE ON FUNCTION deepbible.parse_address(text) TO web_anon;
GRANT EXECUTE ON FUNCTION deepbible.search_verses(text) TO web_anon;
GRANT EXECUTE ON FUNCTION deepbible.verse_dictionary(text) TO web_anon;
