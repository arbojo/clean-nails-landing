-- Fix: migration 010 had phone/name columns swapped in the INSERT.
-- Existing corrupt rows have phone=customer_name and name=phone.
-- Fix everything from order_requests source of truth.

UPDATE customers
SET phone = o.phone,
    name = o.customer_name
FROM order_requests o
WHERE customers.first_order_request_id = o.id
  AND (customers.phone IS DISTINCT FROM o.phone
    OR customers.name IS DISTINCT FROM o.customer_name);

-- Recreate function (already fixed in 010, ensure latest)
CREATE OR REPLACE FUNCTION upsert_customer_on_order_request()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  cid UUID;
BEGIN
  SELECT id INTO cid FROM customers WHERE phone = NEW.phone;

  IF cid IS NULL THEN
    INSERT INTO customers (phone, name, first_order_request_id, last_order_request_id, total_requests)
    VALUES (NEW.phone, NEW.customer_name, NEW.id, NEW.id, 1)
    RETURNING id INTO cid;
  ELSE
    UPDATE customers
    SET
      name = COALESCE(NEW.customer_name, name),
      last_order_request_id = NEW.id,
      total_requests = total_requests + 1,
      updated_at = now()
    WHERE id = cid;
  END IF;

  NEW.customer_id := cid;
  RETURN NEW;
END;
$$;
