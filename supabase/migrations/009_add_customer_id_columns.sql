ALTER TABLE order_requests
ADD COLUMN customer_id UUID REFERENCES customers(id) ON DELETE SET NULL;

CREATE INDEX idx_order_requests_customer ON order_requests (customer_id);

ALTER TABLE analytics_sessions
ADD COLUMN customer_id UUID REFERENCES customers(id) ON DELETE SET NULL;

CREATE INDEX idx_analytics_sessions_customer ON analytics_sessions (customer_id);
