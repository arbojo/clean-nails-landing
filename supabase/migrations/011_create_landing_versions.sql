CREATE TABLE landing_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  landing_id TEXT NOT NULL,
  version TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (landing_id, version)
);

CREATE INDEX idx_landing_versions_landing ON landing_versions (landing_id);
