CREATE TYPE order_status AS ENUM ('new', 'confirmed', 'assigned', 'in_route', 'delivered');

CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  street TEXT NOT NULL,
  colony TEXT NOT NULL,
  city TEXT NOT NULL,
  zip TEXT,
  references TEXT,
  status order_status NOT NULL DEFAULT 'new',
  severity TEXT NOT NULL DEFAULT 'mild',
  product TEXT NOT NULL DEFAULT 'Clean Nails — Dispositivo de Luz',
  total NUMERIC(10,2) NOT NULL DEFAULT 599.00,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_orders_status ON orders (status);
CREATE INDEX idx_orders_phone ON orders (phone);
