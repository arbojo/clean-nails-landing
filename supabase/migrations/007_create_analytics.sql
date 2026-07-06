CREATE TABLE analytics_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at TIMESTAMPTZ,

  landing_id TEXT NOT NULL,
  landing_version TEXT NOT NULL,

  session_token TEXT NOT NULL UNIQUE,

  user_agent TEXT NOT NULL DEFAULT '',
  device_type TEXT NOT NULL DEFAULT '',
  screen_width INTEGER NOT NULL DEFAULT 0,
  screen_height INTEGER NOT NULL DEFAULT 0,
  language TEXT NOT NULL DEFAULT '',
  referrer TEXT NOT NULL DEFAULT '',

  utm_source TEXT NOT NULL DEFAULT '',
  utm_medium TEXT NOT NULL DEFAULT '',
  utm_campaign TEXT NOT NULL DEFAULT '',
  utm_content TEXT NOT NULL DEFAULT '',
  utm_term TEXT NOT NULL DEFAULT '',

  converted BOOLEAN NOT NULL DEFAULT false,
  order_request_id UUID REFERENCES order_requests(id) ON DELETE SET NULL
);

CREATE INDEX idx_analytics_sessions_token ON analytics_sessions (session_token);
CREATE INDEX idx_analytics_sessions_landing ON analytics_sessions (landing_id, landing_version);
CREATE INDEX idx_analytics_sessions_converted ON analytics_sessions (converted);
CREATE INDEX idx_analytics_sessions_created ON analytics_sessions (created_at);

CREATE TABLE analytics_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES analytics_sessions(id) ON DELETE CASCADE,
  event_name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  seconds_from_start INTEGER NOT NULL DEFAULT 0,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX idx_analytics_events_session ON analytics_events (session_id);
CREATE INDEX idx_analytics_events_name ON analytics_events (event_name);
CREATE INDEX idx_analytics_events_created ON analytics_events (created_at);
