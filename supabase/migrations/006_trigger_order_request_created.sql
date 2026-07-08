CREATE OR REPLACE FUNCTION notify_order_request_created()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  payload JSONB;
  fn_url TEXT;
  secret TEXT;
  http_response INTEGER;
BEGIN
  SELECT value INTO fn_url FROM _secrets WHERE key = 'edge_function_url';
  SELECT value INTO secret FROM _secrets WHERE key = 'webhook_secret';

  payload := jsonb_build_object(
    'type', 'ORDER_REQUEST_CREATED',
    'table', 'order_requests',
    'record', jsonb_build_object(
      'id', NEW.id,
      'customer_name', NEW.customer_name,
      'phone', NEW.phone,
      'city', NEW.city,
      'product_name', NEW.product_name,
      'total', NEW.total,
      'support_opt_in', NEW.support_opt_in,
      'metadata', NEW.metadata
    ),
    'old_record', NULL,
    'timestamp', NOW()
  );

  SELECT public.http_post(
    url := fn_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', concat('Bearer ', secret)
    ),
    body := payload::text
  ) INTO http_response;

  RETURN NEW;
END;
$$;

CREATE TRIGGER order_request_created_trigger
  AFTER INSERT ON order_requests
  FOR EACH ROW
  EXECUTE FUNCTION notify_order_request_created();
