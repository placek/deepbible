CREATE TABLE IF NOT EXISTS deepbible._sheets (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT _sheets_pkey PRIMARY KEY (id)
);
