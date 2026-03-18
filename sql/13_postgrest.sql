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

DROP SCHEMA IF EXISTS api CASCADE;
CREATE SCHEMA api;

CREATE OR REPLACE VIEW api._all_sources AS
SELECT *
FROM deepbible._all_sources;

CREATE OR REPLACE FUNCTION api.fetch_verses_by_address(p_address text, p_source text DEFAULT NULL::text)
  RETURNS SETOF deepbible._all_verses
  LANGUAGE sql
  SECURITY DEFINER
  SET search_path = deepbible, public
AS $$
  SELECT *
  FROM deepbible.fetch_verses_by_address(p_address, p_source);
$$;

CREATE OR REPLACE FUNCTION api.fetch_cross_references(p_verse_id text)
  RETURNS TABLE(id text, address text, reference text, rate bigint)
  LANGUAGE sql
  SECURITY DEFINER
  SET search_path = deepbible, public
AS $$
  SELECT *
  FROM deepbible.fetch_cross_references(p_verse_id);
$$;

CREATE OR REPLACE FUNCTION api.fetch_commentaries(p_verse_id text)
  RETURNS TABLE(marker text, text text)
  LANGUAGE sql
  SECURITY DEFINER
  SET search_path = deepbible, public
AS $$
  SELECT *
  FROM deepbible.fetch_commentaries(p_verse_id);
$$;

CREATE OR REPLACE FUNCTION api.fetch_rendered_stories(p_source text, p_address text)
  RETURNS SETOF deepbible._rendered_stories
  LANGUAGE sql
  SECURITY DEFINER
  SET search_path = deepbible, public
AS $$
  SELECT *
  FROM deepbible.fetch_rendered_stories(p_source, p_address);
$$;

CREATE OR REPLACE FUNCTION api.verse_dictionary(p_verse_id text)
  RETURNS TABLE(topic text, word text, meaning text, parse text, forms text[])
  LANGUAGE sql
  SECURITY DEFINER
  SET search_path = deepbible, public
AS $$
  SELECT *
  FROM deepbible.verse_dictionary(p_verse_id);
$$;

CREATE OR REPLACE FUNCTION api.search_verses(search_phrase text)
  RETURNS SETOF deepbible._all_verses
  LANGUAGE sql
  SECURITY DEFINER
  SET search_path = deepbible, public
AS $$
  SELECT *
  FROM deepbible.search_verses(search_phrase);
$$;

GRANT USAGE ON SCHEMA api TO web_anon;
GRANT SELECT ON api._all_sources TO web_anon;
GRANT EXECUTE ON FUNCTION api.fetch_verses_by_address(text, text) TO web_anon;
GRANT EXECUTE ON FUNCTION api.fetch_cross_references(text) TO web_anon;
GRANT EXECUTE ON FUNCTION api.fetch_commentaries(text) TO web_anon;
GRANT EXECUTE ON FUNCTION api.fetch_rendered_stories(text, text) TO web_anon;
GRANT EXECUTE ON FUNCTION api.verse_dictionary(text) TO web_anon;
GRANT EXECUTE ON FUNCTION api.search_verses(text) TO web_anon;
