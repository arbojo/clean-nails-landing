CREATE OR REPLACE FUNCTION assign_customer_on_conversion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- When a session is marked as converted, look up the customer from the order_request
  IF NEW.converted = true AND (OLD.converted = false OR OLD.converted IS NULL) THEN
    IF NEW.order_request_id IS NOT NULL THEN
      SELECT customer_id INTO NEW.customer_id
      FROM order_requests
      WHERE id = NEW.order_request_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER assign_customer_on_conversion_trigger
  BEFORE UPDATE OF converted ON analytics_sessions
  FOR EACH ROW
  WHEN (NEW.converted = true AND (OLD.converted = false OR OLD.converted IS NULL))
  EXECUTE FUNCTION assign_customer_on_conversion();
