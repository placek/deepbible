-- VECTOR EXTENSION
CREATE EXTENSION IF NOT EXISTS vector;

-- EMBEDDINGS TABLE
CREATE TABLE IF NOT EXISTS public._verse_embeddings (
    id UUID PRIMARY KEY,
    embedding vector(1024),
    content TEXT,
    metadata JSONB
);

-- HELPER SQL FUNCTIONS

-- removes basic XML formatting tags from text
CREATE OR REPLACE FUNCTION public.text_without_format(input text)
RETURNS text AS $$
  SELECT regexp_replace(
           regexp_replace(
               input, '</?t>', '', 'g'
           ), '<(br|pb)/?>', '', 'g'
         )
$$ LANGUAGE sql IMMUTABLE;

-- removes metadata XML tags from text
CREATE OR REPLACE FUNCTION public.text_without_metadata(input text)
RETURNS text AS $$
  SELECT regexp_replace(
           input, '<(S|m|f|n|h)>[^<]+</\1>', '', 'g'
         )
$$ LANGUAGE sql IMMUTABLE;

-- removes all known XML tags from text
CREATE OR REPLACE FUNCTION public.raw_text(input text)
RETURNS text AS $$
  SELECT regexp_replace(
           public.text_without_metadata(
             public.text_without_format(
               input
             )
           ), '</?(J|i)>', '', 'g'
         )
$$ LANGUAGE sql IMMUTABLE;

-- removes all known XML tags from text and extracts structured words
CREATE OR REPLACE FUNCTION public.words_with_metadata(input text)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  result jsonb := '[]'::jsonb;
  chunk text;
  word text;
  strong text;
  morph text;
  footnote text;
  note text;
  cleaned text;
BEGIN
  cleaned := public.text_without_format(input);
  cleaned := replace(cleaned, '<i>', '[');
  cleaned := replace(cleaned, '</i>', ']');

  FOR chunk IN
    SELECT unnest(
      regexp_matches(
        cleaned,
        '([^\s<]+(?:<S>\d+</S>|<m>[^<]+</m>|<f>.*?</f>|<n>.*?</n>|<h>.*?</h>)*)',
        'g'
      )
    )
  LOOP
    word := substring(chunk from '^([^\s<]+)');
    strong := substring(chunk from '<S>(\d+)</S>');
    morph := substring(chunk from '<m>([^<]+)</m>');
    footnote := substring(chunk from '<f>(.*?)</f>');
    note := substring(chunk from '<n>(.*?)</n>');
    header := substring(chunk from '<h>(.*?)</h>');

    IF word IS NOT NULL THEN
      result := result || jsonb_strip_nulls(jsonb_build_object(
        'text', word,
        'strong', strong,
        'morph', morph,
        'footnote', footnote,
        'note', note,
        'header', header
      ));
    END IF;
  END LOOP;

  RETURN result;
END;
$$;

-- vector search function
CREATE OR REPLACE FUNCTION public.search_embeddings(
    query_vector vector,
    result_limit INT DEFAULT 5
) RETURNS TABLE (
    id UUID,
    content TEXT,
    metadata JSONB,
    similarity FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        id,
        content,
        metadata,
        1 - (embedding <=> query_vector) AS similarity
    FROM public._verse_embeddings
    ORDER BY embedding <=> query_vector
    LIMIT result_limit;
END;
$$ LANGUAGE plpgsql STABLE;

-- MATERIALIZED VIEWS
DROP MATERIALIZED VIEW IF EXISTS public._raw_verses;
DROP MATERIALIZED VIEW IF EXISTS public._all_verses;
-- all verses from the known schemas
<ALL_VERSES>

-- all_verses with sanitized text
CREATE MATERIALIZED VIEW public._raw_verses AS
SELECT id, language, source, address, source_number, book_number, chapter, verse, public.raw_text(text) AS text
  FROM public._all_verses
WITH NO DATA;
