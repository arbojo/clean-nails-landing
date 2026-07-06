CREATE TABLE customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  phone TEXT NOT NULL UNIQUE,
  name TEXT,

  first_order_request_id UUID REFERENCES order_requests(id) ON DELETE SET NULL,
  last_order_request_id UUID REFERENCES order_requests(id) ON DELETE SET NULL,

  total_requests INTEGER NOT NULL DEFAULT 0,
  total_orders INTEGER NOT NULL DEFAULT 0,

  metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX idx_customers_phone ON customers (phone);
