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
GRANT SELECT ON public.cross_references TO web_anon;
GRANT EXECUTE ON FUNCTION public.parse_address(text) TO web_anon;
GRANT EXECUTE ON FUNCTION public.verses_by_address(text, text) TO web_anon;
GRANT EXECUTE ON FUNCTION public.cross_references(text) TO web_anon;
