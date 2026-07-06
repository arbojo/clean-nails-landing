CREATE TABLE order_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  status TEXT NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'processing', 'converted', 'cancelled')),

  customer_name TEXT NOT NULL,
  phone TEXT NOT NULL,

  street TEXT NOT NULL,
  colony TEXT NOT NULL,
  city TEXT NOT NULL,
  state TEXT NOT NULL DEFAULT '',
  zip TEXT,
  "references" TEXT,

  product_id TEXT,
  product_name TEXT NOT NULL DEFAULT 'Clean Nails — Dispositivo de Luz',
  quantity INTEGER NOT NULL DEFAULT 1,
  total NUMERIC(10,2) NOT NULL DEFAULT 599.00,

  support_opt_in BOOLEAN NOT NULL DEFAULT true,

  metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX idx_order_requests_status ON order_requests (status);
CREATE INDEX idx_order_requests_phone ON order_requests (phone);
