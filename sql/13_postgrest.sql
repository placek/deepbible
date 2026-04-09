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

DROP VIEW IF EXISTS api._all_sources;

CREATE OR REPLACE FUNCTION api._all_sources()
  RETURNS SETOF deepbible._all_sources
  LANGUAGE sql
  SECURITY DEFINER
  SET search_path = deepbible, public
AS $$
  SELECT *
  FROM deepbible._all_sources;
$$;

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

CREATE OR REPLACE FUNCTION api.fetch_cross_references_by_address(p_address text, p_source text DEFAULT NULL::text)
  RETURNS TABLE(address text, reference text, rate bigint)
  LANGUAGE sql
  SECURITY DEFINER
  SET search_path = deepbible, public
AS $$
  SELECT *
  FROM deepbible.fetch_cross_references_by_address(p_address, p_source);
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

DROP FUNCTION IF EXISTS api.upsert_sheet(uuid, jsonb);
CREATE OR REPLACE FUNCTION api.upsert_sheet(p_id uuid, p_data jsonb DEFAULT '{}'::jsonb)
  RETURNS SETOF deepbible._sheets
  LANGUAGE sql
  SECURITY DEFINER
  SET search_path = deepbible, public
AS $$
  INSERT INTO deepbible._sheets (id, data, created_at)
  VALUES (COALESCE(p_id, gen_random_uuid()), p_data, now())
  ON CONFLICT (id) DO UPDATE
  SET data = EXCLUDED.data
  RETURNING *;
$$;

DROP FUNCTION IF EXISTS api.fetch_sheet(uuid);
CREATE OR REPLACE FUNCTION api.fetch_sheet(p_id uuid)
  RETURNS SETOF deepbible._sheets
  LANGUAGE sql
  SECURITY DEFINER
  SET search_path = deepbible, public
AS $$
  SELECT id, data, created_at FROM deepbible._sheets WHERE id = p_id;
$$;

GRANT USAGE ON SCHEMA api TO web_anon;
GRANT EXECUTE ON FUNCTION api._all_sources() TO web_anon;
GRANT EXECUTE ON FUNCTION api.fetch_verses_by_address(text, text) TO web_anon;
GRANT EXECUTE ON FUNCTION api.fetch_cross_references(text) TO web_anon;
GRANT EXECUTE ON FUNCTION api.fetch_cross_references_by_address(text, text) TO web_anon;
GRANT EXECUTE ON FUNCTION api.fetch_commentaries(text) TO web_anon;
GRANT EXECUTE ON FUNCTION api.fetch_rendered_stories(text, text) TO web_anon;
GRANT EXECUTE ON FUNCTION api.verse_dictionary(text) TO web_anon;
GRANT EXECUTE ON FUNCTION api.search_verses(text) TO web_anon;
GRANT EXECUTE ON FUNCTION api.upsert_sheet(uuid, jsonb) TO web_anon;
GRANT EXECUTE ON FUNCTION api.fetch_sheet(uuid) TO web_anon;
