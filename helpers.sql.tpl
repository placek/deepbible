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
DROP FUNCTION IF EXISTS public.text_without_format(text);
CREATE OR REPLACE FUNCTION public.text_without_format(input text)
  RETURNS text
  LANGUAGE 'sql'
  COST 100
  IMMUTABLE PARALLEL UNSAFE
AS $BODY$
  SELECT regexp_replace(input, '</?(strong|b|br|div|pb|t)[^>]*>', '', 'ig')
$BODY$;

-- removes metadata XML tags from text
DROP FUNCTION IF EXISTS public.text_without_metadata(text);
CREATE OR REPLACE FUNCTION public.text_without_metadata(input text)
  RETURNS text
  LANGUAGE 'plpgsql'
  COST 100
  IMMUTABLE PARALLEL UNSAFE
AS $BODY$
DECLARE
  output text := input;
  new_output text;
BEGIN
  LOOP
    new_output := regexp_replace(output, '<(S|m|f|n|h)>[^<>]*</\1>', '', 'g');
    EXIT WHEN new_output = output;
    output := new_output;
  END LOOP;
  RETURN output;
END;
$BODY$;

-- removes all known XML tags from text
DROP FUNCTION IF EXISTS public.raw_text(text);
CREATE OR REPLACE FUNCTION public.raw_text(input text)
  RETURNS text
  LANGUAGE 'sql'
  COST 100
  IMMUTABLE PARALLEL UNSAFE
AS $BODY$
  SELECT regexp_replace(public.text_without_metadata(public.text_without_format(input)), '</?(J|i)>', '', 'g')
$BODY$;

-- splits text into words with associated metadata (strong, morph, footnote, note, header)
DROP FUNCTION IF EXISTS public.words_with_metadata(text);
CREATE OR REPLACE FUNCTION public.words_with_metadata(input text)
  RETURNS jsonb
  LANGUAGE 'plpgsql'
  COST 100
  VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
  result   jsonb := '[]'::jsonb;
  word     text;
  tags     text;   -- all tags that follow the word (space-separated in the source)
  strong   text;
  morph    text;
  footnote text;
  note     text;
  header   text;
  cleaned  text;
BEGIN
  cleaned := public.text_without_format(input);
  cleaned := replace(cleaned, '<i>', '[');
  cleaned := replace(cleaned, '</i>', ']');

  -- 1st group = the word (no whitespace or '<')
  -- 2nd group = zero or more following tags belonging to that word
  FOR word, tags IN
    SELECT m[1], m[2]
    FROM regexp_matches(
      cleaned,
      '([^\s<]+)' ||
      '((?:\s*(?:<S>[^<]+</S>|<m>[^<]+</m>|<f>[^<]+</f>|<n>[^<]+</n>|<h>[^<]+</h>))*)',
      'g'
    ) AS m
  LOOP
    -- pull fields from the collected tags blob
    strong   := substring(tags from '<S>([^<]+)</S>');
    morph    := substring(tags from '<m>([^<]+)</m>');
    footnote := substring(tags from '<f>([^<]+)</f>');
    note     := substring(tags from '<n>([^<]+)</n>');
    header   := substring(tags from '<h>([^<]+)</h>');

    result := result || jsonb_build_array(
      jsonb_strip_nulls(jsonb_build_object(
        'text',     word,
        'strong',   strong,
        'morph',    morph,
        'footnote', footnote,
        'note',     note,
        'header',   header
      ))
    );
  END LOOP;

  RETURN result;
END;
$BODY$;

-- parses a Bible address
DROP FUNCTION IF EXISTS public.parse_address(text);
CREATE OR REPLACE FUNCTION public.parse_address(address text)
  RETURNS TABLE(book text, chapter integer, verse integer)
  LANGUAGE 'plpgsql'
  COST 100
  VOLATILE PARALLEL UNSAFE
  ROWS 1000
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
DROP FUNCTION IF EXISTS public.verses_by_address(text, text, text);
CREATE OR REPLACE FUNCTION public.verses_by_address(p_address text, p_language text DEFAULT NULL::text, p_source text DEFAULT NULL::text)
  RETURNS TABLE(id text, verses jsonb)
  LANGUAGE 'plpgsql'
  COST 100
  VOLATILE PARALLEL UNSAFE
  ROWS 1000
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

-- retrieves verses by filters, grouped by book, chapter, and verse
DROP FUNCTION IF EXISTS public.verses_by_filters(text, text, text, integer, integer);
CREATE OR REPLACE FUNCTION public.verses_by_filters(p_language text DEFAULT NULL::text, p_source text DEFAULT NULL::text, p_book_short_name text DEFAULT NULL::text, p_chapter integer DEFAULT NULL::integer, p_verse integer DEFAULT NULL::integer)
  RETURNS TABLE(id text, verses jsonb)
  LANGUAGE 'plpgsql'
  COST 100
  VOLATILE PARALLEL UNSAFE
  ROWS 1000
AS $BODY$
BEGIN
  RETURN QUERY
  SELECT v.book_number || '/' || v.chapter || '/' || v.verse AS id,
         jsonb_agg(
           jsonb_build_object(
             'id', v.id,
             'language', v.language,
             'source', v.source,
             'address', v.address,
             'text', v.text
           )
           ORDER BY v.verse
         ) AS verses
  FROM _all_verses v
  WHERE (p_language IS NULL OR v.language = p_language)
    AND (p_source IS NULL OR v.source = p_source)
    AND (
         p_book_short_name IS NULL
         OR v.book_number IN (
             SELECT book_number FROM _all_books WHERE short_name = p_book_short_name
           )
        )
    AND (p_chapter IS NULL OR v.chapter = p_chapter)
    AND (p_verse IS NULL OR v.verse = p_verse)
  GROUP BY v.book_number, v.chapter, v.verse;
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
