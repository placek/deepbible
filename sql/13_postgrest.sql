DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'web_anon') THEN
    CREATE ROLE web_anon NOLOGIN;
  END IF;
END
$$;
--CREATE ROLE authenticator NOINHERIT LOGIN PASSWORD 'authpass';
--GRANT web_anon TO authenticator;

GRANT USAGE ON SCHEMA public TO web_anon;
GRANT SELECT ON public._all_sources TO web_anon;
GRANT SELECT ON public._all_books TO web_anon;
GRANT SELECT ON public._all_verses TO web_anon;
GRANT SELECT ON public._all_commentaries TO web_anon;
GRANT SELECT ON public._cross_references TO web_anon;
GRANT SELECT ON public._rendered_stories TO web_anon;
GRANT EXECUTE ON FUNCTION public.fetch_commentaries(text) TO web_anon;
GRANT EXECUTE ON FUNCTION public.fetch_cross_references(text) TO web_anon;
GRANT EXECUTE ON FUNCTION public.fetch_rendered_stories(text, text) TO web_anon;
GRANT EXECUTE ON FUNCTION public.fetch_verses_by_address(text, text) TO web_anon;
GRANT EXECUTE ON FUNCTION public.parse_address(text) TO web_anon;
GRANT EXECUTE ON FUNCTION public.search_verses(text) TO web_anon;
