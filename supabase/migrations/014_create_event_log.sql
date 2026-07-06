-- event_log table for webhook idempotency
CREATE TABLE IF NOT EXISTS event_log (
  event_id TEXT PRIMARY KEY,
  order_id TEXT,
  event_type TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'new',
  payload JSONB,
  success BOOLEAN DEFAULT false,
  error TEXT,
  processed_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_event_log_event_type ON event_log (event_type);
CREATE INDEX IF NOT EXISTS idx_event_log_success ON event_log (success);
