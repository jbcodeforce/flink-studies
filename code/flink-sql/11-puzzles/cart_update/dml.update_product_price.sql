-- Product price decrease: fans out to C1 and C2 via upsert join (both contain P001).
-- Downstream can diff consecutive integrated_cart upserts to trigger price-drop alerts.
INSERT INTO products (product_id, name, description, price, availability)
VALUES ('P001', 'Laptop', '15-inch laptop', CAST(899.00 AS DECIMAL(10, 2)), TRUE);
