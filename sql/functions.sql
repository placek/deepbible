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
  m TEXT[];
  part TEXT;
  start_verse INT;
  end_verse INT;
  v INT;
BEGIN
  m := regexp_match(trim(address), '^(\d?\s*[[:alpha:]żźćńółęąśŻŹĆĄŚĘŁÓŃ]+)\s+(\d+),\s*([\d\.\-]+)$');
  IF m IS NOT NULL THEN
    book    := trim(regexp_replace(m[1], '\s+', ' ', 'g'));
    chapter := m[2]::INT;
    FOR part IN SELECT unnest(string_to_array(m[3], '.')) LOOP
      IF position('-' IN part) > 0 THEN
        start_verse := split_part(part, '-', 1)::INT;
        end_verse   := split_part(part, '-', 2)::INT;
        IF end_verse < start_verse THEN
          RAISE EXCEPTION 'Invalid verse range: % in %', part, address;
        END IF;
        FOR v IN start_verse..end_verse LOOP
          verse := v;
          RETURN NEXT;
        END LOOP;
      ELSE
        verse := part::INT;
        RETURN NEXT;
      END IF;
    END LOOP;
    RETURN;
  END IF;
  m := regexp_match(trim(address), '^(\d?\s*[[:alpha:]żźćńółęąśŻŹĆĄŚĘŁÓŃ]+)\s+(\d+)$');
  IF m IS NOT NULL THEN
    book    := trim(regexp_replace(m[1], '\s+', ' ', 'g'));
    chapter := m[2]::INT;
    verse   := NULL;
    RETURN NEXT;
    RETURN;
  END IF;
  RAISE EXCEPTION 'Invalid address format: %', address;
END;
$BODY$;

-- retrieves verses by address, filtered by language, and source
DROP FUNCTION IF EXISTS public.verses_by_address(text, text, text);
CREATE OR REPLACE FUNCTION public.verses_by_address(p_address text, p_language text DEFAULT NULL::text, p_source text DEFAULT NULL::text)
  RETURNS TABLE(book_number integer, chapter integer, verse integer, verse_id text, language text, source text, address text, text text)
  LANGUAGE 'plpgsql'
  COST 100
  VOLATILE PARALLEL UNSAFE
  ROWS 1000
AS $BODY$
BEGIN
  RETURN QUERY
  WITH addresses AS (
    SELECT DISTINCT
      b.book_number::int AS book_number,
      a.chapter::int     AS chapter,
      a.verse            AS verse
    FROM parse_address(p_address) a
    JOIN public._all_books b
      ON a.book = b.short_name
  )
  SELECT DISTINCT
    v.book_number::int AS book_number,
    v.chapter::int     AS chapter,
    v.verse::int       AS verse,
    v.id               AS verse_id,
    v.language,
    v.source,
    v.address,
    raw_text(v.text)   AS "text"
  FROM addresses a
  JOIN public._all_verses v
    ON v.book_number = a.book_number
   AND v.chapter = a.chapter
   AND (a.verse IS NULL OR v.verse = a.verse)
  WHERE
    (p_language IS NULL OR v.language = p_language)
    AND (p_source IS NULL OR v.source = p_source)
  ORDER BY book_number, chapter, verse, language, source, verse_id;
END;
$BODY$;
