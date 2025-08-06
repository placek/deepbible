-- VECTOR EXTENSION
-- CREATE EXTENSION IF NOT EXISTS vector;

-- EMBEDDINGS TABLE
-- CREATE TABLE IF NOT EXISTS public._verse_embeddings (
--     id UUID PRIMARY KEY,
--     embedding vector(1024),
--     content TEXT,
--     metadata JSONB
-- );

<ALL_VERSES>

-- HELPER SQL FUNCTIONS

-- removes basic XML formatting tags from text
CREATE OR REPLACE FUNCTION public.text_without_format(input text)
RETURNS text AS $$
  SELECT regexp_replace(input, '</?(strong|b|br|div|pb|t)[^>]*>', '', 'ig')
$$ LANGUAGE sql IMMUTABLE;

-- removes metadata XML tags from text
CREATE OR REPLACE FUNCTION public.text_without_metadata(input text)
RETURNS text AS $$
DECLARE
  output text := input;
  new_output text;
BEGIN
  LOOP
    -- Try to remove one level of matched metadata tags
    new_output := regexp_replace(
      output,
      '<(S|m|f|n|h)>[^<>]*</\1>',
      '',
      'g'
    );

    -- Exit when nothing changes
    EXIT WHEN new_output = output;
    output := new_output;
  END LOOP;

  RETURN output;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

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
  header text;
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

-- parses a Bible address
CREATE OR REPLACE FUNCTION public.parse_address(address text)
  RETURNS TABLE(book text, chapter integer, verse integer)
  LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
  segment TEXT;
  matches TEXT[];
  verses_part TEXT;
  start_verse INT;
  end_verse INT;
  v INT;
BEGIN
  matches := regexp_match(trim(address), '^(\d?[[:alpha:]żźćńółęąśŻŹĆĄŚĘŁÓŃ]+)\s+(\d+),([\d\.-]+)$');
  IF matches IS NULL THEN
    RAISE EXCEPTION 'Invalid address format: %', address;
  END IF;
  book := matches[1];
  chapter := matches[2]::INT;
  verses_part := matches[3];
  FOR segment IN SELECT unnest(string_to_array(verses_part, '.')) LOOP
    IF position('-' IN segment) > 0 THEN
      start_verse := split_part(segment, '-', 1)::INT;
      end_verse   := split_part(segment, '-', 2)::INT;
      FOR v IN start_verse..end_verse LOOP
        verse := v;
        RETURN NEXT;
      END LOOP;
    ELSE
      verse := segment::INT;
      RETURN NEXT;
    END IF;
  END LOOP;
END;
$BODY$;

-- retrieves verses by address, filtered by language, and source
CREATE OR REPLACE FUNCTION verses_by_address(p_address TEXT, p_language TEXT DEFAULT NULL, p_source TEXT DEFAULT NULL)
  RETURNS TABLE (id TEXT, verses JSONB)
  LANGUAGE 'plpgsql'
AS $BODY$
BEGIN
  RETURN QUERY
  WITH
    addresses AS (
      SELECT b.book_number, a.chapter, a.verse
      FROM parse_address(p_address) a
      JOIN _all_books b ON a.book = b.short_name
    ),
    verses_raw AS (
      SELECT v.book_number, v.chapter, v.verse, v.id, v.language, v.source, v.address, raw_text(v.text) AS text
      FROM addresses a
      JOIN public._all_verses v
        ON v.book_number = a.book_number AND v.chapter = a.chapter AND v.verse = a.verse
      WHERE
        (p_language IS NULL OR v.language = p_language)
        AND (p_source IS NULL OR v.source = p_source)
    )
  SELECT verses_raw.book_number || '/' || verses_raw.chapter || '/' || verses_raw.verse AS id,
    jsonb_agg(jsonb_build_object('id', verses_raw.id, 'language', verses_raw.language, 'source', verses_raw.source, 'address', verses_raw.address, 'text', verses_raw.text)) AS verses
  FROM verses_raw
  GROUP BY verses_raw.book_number, verses_raw.chapter, verses_raw.verse;
END;
$BODY$;

-- vector search function
-- CREATE OR REPLACE FUNCTION public.search_embeddings(
--     query_vector vector,
--     result_limit INT DEFAULT 5
-- ) RETURNS TABLE (
--     id UUID,
--     content TEXT,
--     metadata JSONB,
--     similarity FLOAT
-- ) AS $$
-- BEGIN
--     RETURN QUERY
--     SELECT
--         id,
--         content,
--         metadata,
--         1 - (embedding <=> query_vector) AS similarity
--     FROM public._verse_embeddings
--     ORDER BY embedding <=> query_vector
--     LIMIT result_limit;
-- END;
-- $$ LANGUAGE plpgsql STABLE;
