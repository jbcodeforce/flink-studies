-- Seed product catalog.
INSERT INTO products (product_id, name, description, price, availability)
VALUES
    ('P001', 'Laptop', '15-inch laptop', CAST(999.00 AS DECIMAL(10, 2)), TRUE),
    ('P002', 'Mouse', 'Wireless mouse', CAST(29.00 AS DECIMAL(10, 2)), TRUE),
    ('P003', 'Keyboard', 'Mechanical keyboard', CAST(79.00 AS DECIMAL(10, 2)), TRUE);
