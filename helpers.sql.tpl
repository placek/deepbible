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

-- removes basic XML tags from text
CREATE OR REPLACE FUNCTION public.strip_basic_tags(input text)
RETURNS text AS $$
  SELECT regexp_replace(input, '</?(div|q|Q|x|X|E|g|G|WW|small|t)(\s[^<>]*)?/?>', '', 'gi');
$$ LANGUAGE sql IMMUTABLE;

-- removes all known XML tags from text
CREATE OR REPLACE FUNCTION public.sanitize_text(input text)
RETURNS text AS $$
  SELECT regexp_replace(
           regexp_replace(
             regexp_replace(
               regexp_replace(
                 regexp_replace(
                   regexp_replace(
                     regexp_replace(
                       regexp_replace(
                         regexp_replace(input,
                           '<(S|m|f|n)(\s[^<>]*)?>.*?</\1>', '', 'gi'),
                         '<(S|m|f|n)(\s[^<>]*)?/?>', '', 'gi'),
                       '</?(J|e|i)(\s[^<>]*)?/?>', '', 'gi'),
                     '<(br|pb)(\s[^<>]*)?/?>', '', 'gi'),
                   '<(/)?[a-zA-Z0-9]+[^<>]*>', '', 'g'),
                 '<>', '', 'g'),
               '[<>]+', '', 'g'),
             '\s+', ' ', 'g'),
           '^\s+|\s+$', '', 'g');
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
   -- 1. Replace <i> with [ and </i> with ]
  cleaned := replace(input, '<i>', '[');
  cleaned := replace(cleaned, '</i>', ']');

  -- 2. Remove irrelevant tags
  cleaned := regexp_replace(cleaned, '<\/?(J|pb|br|div|small|e|t)[^>]*>', '', 'gsi');

  -- 3. Extract word + tag groups
  FOR chunk IN
    SELECT unnest(
      regexp_matches(
        cleaned,
        '([^\s<]+(?:<S>\d+</S>|<m>[^<]+</m>|<f>.*?</f>|<n>.*?</n>)*)',
        'g'
      )
    )
  LOOP
    word := substring(chunk from '^([^\s<]+)');
    strong := substring(chunk from '<S>(\d+)</S>');
    morph := substring(chunk from '<m>([^<]+)</m>');
    footnote := substring(chunk from '<f>(.*?)</f>');
    note := substring(chunk from '<n>(.*?)</n>');

    -- Clean nested <small> inside notes/footnotes
    IF footnote IS NOT NULL THEN
      footnote := regexp_replace(footnote, '<small[^>]*>.*?</small>', '', 'g');
    END IF;
    IF note IS NOT NULL THEN
      note := regexp_replace(note, '<small[^>]*>.*?</small>', '', 'g');
    END IF;

    IF word IS NOT NULL THEN
      result := result || jsonb_strip_nulls(jsonb_build_object(
        'text', word,
        'strong', strong,
        'morph', morph,
        'footnote', footnote,
        'note', note
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
DROP MATERIALIZED VIEW IF EXISTS public._sanitized_verses;
DROP MATERIALIZED VIEW IF EXISTS public._all_verses;
-- all verses from the known schemas
<ALL_VERSES>

REFRESH MATERIALIZED VIEW public._all_verses;

-- all_verses with sanitized text
CREATE MATERIALIZED VIEW public._sanitized_verses AS
SELECT id, language, source, address, source_number, book_number, chapter, verse,
       public.sanitize_text(text) AS text
  FROM public._all_verses
WITH NO DATA;

REFRESH MATERIALIZED VIEW public._sanitized_verses;

DROP INDEX IF EXISTS idx_sanitized_verses_language;
CREATE INDEX idx_sanitized_verses_language ON public._sanitized_verses(language);
DROP INDEX IF EXISTS idx_sanitized_verses_book_chapter_verse;
CREATE INDEX idx_sanitized_verses_book_chapter_verse ON public._sanitized_verses(book_number, chapter, verse);
DROP INDEX IF EXISTS idx_sanitized_verses_source_number;
CREATE INDEX idx_sanitized_verses_source_number ON public._sanitized_verses(source_number);
