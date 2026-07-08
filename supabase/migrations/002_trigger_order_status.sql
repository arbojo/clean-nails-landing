CREATE OR REPLACE FUNCTION notify_order_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  fn_url TEXT;
  secret TEXT;
  http_response INTEGER;
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    SELECT value INTO fn_url FROM _secrets WHERE key = 'edge_function_url';
    SELECT value INTO secret FROM _secrets WHERE key = 'webhook_secret';

    SELECT public.http_post(
      url := fn_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || secret
      ),
      body := jsonb_build_object(
        'type', 'ORDER_STATUS_CHANGE',
        'table', 'orders',
        'record', row_to_json(NEW),
        'old_record', row_to_json(OLD),
        'timestamp', now()
      )
    ) INTO http_response;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_order_status_change
  AFTER UPDATE OF status ON orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_order_status_change();
