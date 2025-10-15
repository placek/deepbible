DROP FUNCTION IF EXISTS public.get_cross_references(text);
CREATE OR REPLACE FUNCTION public.get_cross_references(p_verse_id text)
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
        THEN (COALESCE(b1.short_name,'') || ' ' || cr.c1 || '.' || cr.v1 || '-' || cr.v2)

        -- different book and/or chapter with b2,c2,v2 -> Book1 C1.V1-Book2 C2.V2
        WHEN cr.b2 IS NOT NULL AND cr.c2 IS NOT NULL AND cr.v2 IS NOT NULL
        THEN (COALESCE(b1.short_name,'') || ' ' || cr.c1 || '.' || cr.v1
              || '-' ||
              COALESCE(b2.short_name,'') || ' ' || cr.c2 || '.' || cr.v2)

        -- only from reference -> Book1 C1.V1
        ELSE (COALESCE(b1.short_name,'') || ' ' || cr.c1 || '.' || cr.v1)
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
