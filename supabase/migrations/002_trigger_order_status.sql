CREATE OR REPLACE FUNCTION notify_order_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    PERFORM
      net.http_post(
        url := current_setting('app.settings.edge_function_url', true) || '/functions/send-order-event',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || current_setting('app.settings.edge_function_secret', true)
        ),
        body := jsonb_build_object(
          'type', 'ORDER_STATUS_CHANGE',
          'table', 'orders',
          'record', row_to_json(NEW),
          'old_record', row_to_json(OLD),
          'timestamp', now()
        )
      );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_order_status_change
  AFTER UPDATE OF status ON orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_order_status_change();
