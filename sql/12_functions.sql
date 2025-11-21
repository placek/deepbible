CREATE EXTENSION IF NOT EXISTS pg_trgm;

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
  m := regexp_match(trim(address), '^(.+)\s+(\d+),\s*([\d\.\-]+)$');
  IF m IS NOT NULL THEN
    book    := m[1];
    chapter := m[2]::INT;
    FOR part IN SELECT unnest(string_to_array(m[3], '.')) LOOP
      IF position('-' IN part) > 0 THEN
        start_verse := split_part(part, '-', 1)::INT;
        end_verse   := NULLIF(split_part(part, '-', 2), '')::INT;
        IF end_verse IS NULL THEN
          end_verse := 999;
        END IF;
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
  m := regexp_match(trim(address), '^(.+)\s+(\d+)$');
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
DROP FUNCTION IF EXISTS public.verses_by_address(text, text);
CREATE OR REPLACE FUNCTION public.verses_by_address(p_address text, p_source text DEFAULT NULL::text)
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
    text_without_format(v.text) AS "text"
  FROM addresses a
  JOIN public._all_verses v
    ON v.book_number = a.book_number
   AND v.chapter = a.chapter
   AND (a.verse IS NULL OR v.verse = a.verse)
  WHERE
    p_source IS NULL OR v.source = p_source
  ORDER BY book_number, chapter, verse, language, source, verse_id;
END;
$BODY$;

-- retrieves cross-references for a given verse_id
DROP FUNCTION IF EXISTS public.cross_references(text);
CREATE OR REPLACE FUNCTION public.cross_references(p_verse_id text)
  RETURNS TABLE(id text, address text, reference text, rate bigint)
  LANGUAGE 'plpgsql'
  COST 100
  VOLATILE PARALLEL UNSAFE
  ROWS 1000
AS $BODY$
DECLARE
  v_language      text;
  v_source_number public._all_books.source_number%TYPE;
  v_book_number   public.cross_references.book_number%TYPE;
  v_chapter       public.cross_references.chapter%TYPE;
  v_verse         public.cross_references.verse%TYPE;
BEGIN
  -- Parse p_verse_id = <language>/<source>/<book>/<chapter>/<verse>
  v_language := NULLIF(split_part(p_verse_id, '/', 1), '');
  -- Cast to concrete SQL types (no %TYPE in casts)
  v_source_number := split_part(p_verse_id, '/', 2)::int;
  v_book_number   := split_part(p_verse_id, '/', 3)::bigint;
  v_chapter       := split_part(p_verse_id, '/', 4)::int;
  v_verse         := split_part(p_verse_id, '/', 5)::int;

  IF v_language IS NULL
     OR split_part(p_verse_id, '/', 2) = ''
     OR split_part(p_verse_id, '/', 3) = ''
     OR split_part(p_verse_id, '/', 4) = ''
     OR split_part(p_verse_id, '/', 5) = '' THEN
    RAISE EXCEPTION
      'Invalid p_verse_id format. Expected <language>/<source_number>/<book_number>/<chapter>/<verse>, got: %',
      p_verse_id;
  END IF;

  RETURN QUERY
  WITH books AS (
    SELECT ab.book_number, ab.short_name
    FROM public._all_books AS ab
    WHERE ab.source_number = v_source_number
      AND ab.language = v_language
  )
  SELECT
      p_verse_id,
      (b.short_name || ' ' || cr.chapter || ',' || cr.verse) AS address,
      CASE
        -- same book & chapter and have b2,c2,v2 -> Book C.V1-V2
        WHEN cr.b2 IS NOT NULL AND cr.c2 IS NOT NULL AND cr.v2 IS NOT NULL
             AND cr.b1 = cr.b2 AND cr.c1 = cr.c2
        THEN (COALESCE(b1.short_name,'') || ' ' || cr.c1 || ',' || cr.v1 || '-' || cr.v2)

        -- different book and/or chapter with b2,c2,v2 -> Book1 C1.V1-Book2 C2.V2
        WHEN cr.b2 IS NOT NULL AND cr.c2 IS NOT NULL AND cr.v2 IS NOT NULL
        THEN (COALESCE(b1.short_name,'') || ' ' || cr.c1 || ',' || cr.v1 || '-')

        -- only from reference -> Book1 C1.V1
        ELSE (COALESCE(b1.short_name,'') || ' ' || cr.c1 || ',' || cr.v1)
      END AS reference,
      cr.rate
  FROM public.cross_references AS cr
  LEFT JOIN books AS b  ON cr.book_number = b.book_number
  LEFT JOIN books AS b1 ON cr.b1 = b1.book_number
  LEFT JOIN books AS b2 ON cr.b2 = b2.book_number
  WHERE cr.book_number = v_book_number
    AND cr.chapter     = v_chapter
    AND cr.verse       = v_verse
  ORDER BY cr.rate DESC, cr.book_number, cr.chapter, cr.verse;

END;
$BODY$;

-- retrieves commentaries for a given verse_id
DROP FUNCTION IF EXISTS public.commentaries(text);
CREATE OR REPLACE FUNCTION public.commentaries(p_verse_id text)
  RETURNS TABLE(marker text, text text)
  LANGUAGE 'plpgsql'
  COST 100
  VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
  v_language          text;
  v_source_number     public._all_commentaries.source_number%TYPE;
  v_book_number_text  text;
  v_chapter_text      text;
  v_verse_text        text;
  v_book_number       public._all_commentaries.book_number%TYPE;
  v_chapter           integer;
  v_verse             integer;
  v_position          numeric;
BEGIN
  v_language      := NULLIF(split_part(p_verse_id, '/', 1), '');
  v_source_number := NULLIF(split_part(p_verse_id, '/', 2), '');
  v_book_number_text := NULLIF(split_part(p_verse_id, '/', 3), '');
  v_chapter_text     := NULLIF(split_part(p_verse_id, '/', 4), '');
  v_verse_text       := NULLIF(split_part(p_verse_id, '/', 5), '');

  IF v_language IS NULL
     OR v_source_number IS NULL
     OR v_book_number_text IS NULL
     OR v_chapter_text IS NULL
     OR v_verse_text IS NULL THEN
    RAISE EXCEPTION
      'Invalid p_verse_id format. Expected <language>/<source_number>/<book_number>/<chapter>/<verse>, got: %',
      p_verse_id;
  END IF;

  v_book_number := v_book_number_text::numeric;
  v_chapter     := v_chapter_text::integer;
  v_verse       := v_verse_text::integer;
  v_position    := v_chapter::numeric * 1000 + v_verse::numeric;

  RETURN QUERY
  SELECT
    ac.marker,
    ac.text
  FROM public._all_commentaries ac
  WHERE ac.language      = v_language
    AND ac.source_number = v_source_number
    AND ac.book_number   = v_book_number
    AND v_position BETWEEN (ac.chapter_number_from * 1000 + ac.verse_number_from)
                       AND (ac.chapter_number_to   * 1000 + ac.verse_number_to)
  ORDER BY ac.chapter_number_from, ac.verse_number_from, ac.marker;
END;
$BODY$;

DROP FUNCTION IF EXISTS public.search_verses(text);
CREATE OR REPLACE FUNCTION public.search_verses(search_phrase text)
  RETURNS SETOF _all_verses
  LANGUAGE 'plpgsql'
  COST 100
  VOLATILE PARALLEL UNSAFE
  ROWS 1000
AS $BODY$
DECLARE
  v_source  text;
  v_address text;
  v_term    text;
BEGIN
  v_source := substring(search_phrase from '@([^\s]+)');
  v_address := substring(search_phrase from '~([^\s]*(\s+\d+(,\d+)?)?)');
  v_term := trim(regexp_replace(regexp_replace(search_phrase, '@\S+\s*', '', 'gi'), '~\S*(\s+\d+(,\d+)?)?\s*', '', 'gi'));

  IF v_term IS NULL OR v_term !~ '\w' THEN
    v_term := NULL;
  END IF;

  RETURN QUERY
  SELECT *
  FROM public._all_verses v
  WHERE (v_source  IS NULL OR v.source = v_source)
    AND (v_address IS NULL OR v.address ILIKE
           CASE
           WHEN strpos(v_address, ' ') = 0 THEN v_address || ' %'
           WHEN strpos(v_address, ',') = 0 THEN v_address || ',%'
           ELSE v_address
           END
        )
    AND (v_term    IS NULL OR v.text ILIKE '%' || v_term || '%')
  ORDER BY CASE
           WHEN v_term IS NULL THEN -(book_number * 1000 + chapter * 100 + verse)
           ELSE similarity(v.text, COALESCE(v_term, search_phrase))
           END DESC
  LIMIT 500;
END;
$BODY$;
