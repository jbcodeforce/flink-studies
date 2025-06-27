ALTER TABLE products ADD COLUMN discount_id INT;

ALTER TABLE products
ADD CONSTRAINT fk_products_discount
FOREIGN KEY (discount_id) REFERENCES discounts(discount_id) ON DELETE SET NULL;