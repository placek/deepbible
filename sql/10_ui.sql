CREATE TABLE IF NOT EXISTS deepbible._sheets (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT _sheets_pkey PRIMARY KEY (id)
);

ALTER TABLE deepbible._sheets ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();
