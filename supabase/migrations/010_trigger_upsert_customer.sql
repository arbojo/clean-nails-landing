CREATE OR REPLACE FUNCTION upsert_customer_on_order_request()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  cid UUID;
BEGIN
  -- Try to find existing customer by phone
  SELECT id INTO cid FROM customers WHERE phone = NEW.phone;

  IF cid IS NULL THEN
    -- Create new customer
    INSERT INTO customers (phone, name, first_order_request_id, last_order_request_id, total_requests)
    VALUES (NEW.customer_name, NEW.phone, NEW.id, NEW.id, 1)
    RETURNING id INTO cid;
  ELSE
    -- Update existing customer
    UPDATE customers
    SET
      name = COALESCE(NEW.customer_name, name),
      last_order_request_id = NEW.id,
      total_requests = total_requests + 1,
      updated_at = now()
    WHERE id = cid;
  END IF;

  -- Set customer_id on the order_request
  NEW.customer_id := cid;

  RETURN NEW;
END;
$$;

CREATE TRIGGER upsert_customer_trigger
  BEFORE INSERT ON order_requests
  FOR EACH ROW
  EXECUTE FUNCTION upsert_customer_on_order_request();
