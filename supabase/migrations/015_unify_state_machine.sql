-- ============================================================
-- Migration 015 — Unificar State Machine + Idempotencia
-- ============================================================
-- 1. Agregar valores faltantes al enum order_status
ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'cancelled';
ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'failed';

-- 2. Migrar datos legacy al nuevo estado unificado
UPDATE orders SET status = 'confirmed' WHERE status IN ('pending_review', 'preorder');
UPDATE orders SET status = 'in_route'   WHERE status = 'waiting';
UPDATE orders SET status = 'failed'     WHERE status IN ('rejected');
UPDATE orders SET status = 'delivered'  WHERE status = 'archived';
UPDATE orders SET status = 'confirmed'  WHERE status = 'pending';

-- 3. Unique constraint para idempotencia de notificaciones
--    (order_id, status, event_type) debe ser único
ALTER TABLE event_log DROP CONSTRAINT IF EXISTS uq_event_notification;
DELETE FROM event_log WHERE event_id IS NULL OR event_id = '';
ALTER TABLE event_log ADD CONSTRAINT uq_event_notification
  UNIQUE (order_id, status, event_type);

-- 4. Asegurar índices
CREATE INDEX IF NOT EXISTS idx_event_log_order_id ON event_log (order_id);
CREATE INDEX IF NOT EXISTS idx_orders_updated_at ON orders (updated_at);
