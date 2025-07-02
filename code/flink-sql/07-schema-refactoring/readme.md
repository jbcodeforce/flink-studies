# A schema evolution study

The goal of this chapter is to demonstrate schema evolution for a transactional database. The high-level architecture looks like:



There is a source Table in Postgresql that includes a simple schema like

```sql
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL,
    product_category VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    stock_quantity INT NOT NULL DEFAULT 0,
    discount DECIMAL(10, 2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

A cdc debezium postgresql source connector creates the schema v1 and pushes records from the products table to a products topic in kafka. A Flink job is processing and creates a table for public consumption as a data product. This process is illustrated by the top level flow in the following diagram:

![](./images/arch_1.drawio.png)

An example of simple Flink statement building a public Data as a product could be to aggregate discount offered by product category:

```sql
create table if not exists product_discount (
    product_category VARCHAR(255) NOT NULL,
    average_discount float
) distributed hash(product_category) in 1 buckets
 with (

 )
```

## Problem statement

The products table at the source SQL database is refactorized by separating the discount value to become an entity and a table:

```sql
CREATE TABLE discounts (
    discount_id SERIAL PRIMARY KEY,
    discount_name VARCHAR(255) NOT NULL,
    discount_type VARCHAR(50) NOT NULL, -- e.g., 'percentage', 'fixed_amount'
    discount_value DECIMAL(5, 2) NOT NULL, -- e.g., 0.10 for 10%, or 5.00 for $5
    start_date DATE,
    end_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

Therefore the products table uses a foreign key:

```sql
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    stock_quantity INT NOT NULL DEFAULT 0,
    discount_id INT,
    FOREIGN KEY (discount_id) REFERENCES discounts(discount_id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

The Flink statement needs, now, to support a join between two tables, but being able to process old schema products records with the new schema records to get the correct aggregation.

![](./images/arch_2.drawio.png)

From a consumer of the data as a product topic, there will be no difference.

In the table refactoring, the products is keeping the discount values for older record but will get null value once the discount_id foreign key is present. The discount column will never be dropped. 

The flink statement needs to do a join under conditions.

```sql
SELECT
    p.category_name,
    AVG(CASE
            WHEN d.discount_type = 'percentage' THEN p.price * d.discount_value
            WHEN d.discount_type = 'fixed_amount' THEN d.discount_value
            ELSE 0 -- Handle cases where discount_type is not recognized or null
        END) AS average_discount_amount
FROM
    products AS p
LEFT JOIN
    discounts AS d ON p.discount_id = d.discount_id
WHERE
    d.is_active IS TRUE -- Only consider active discounts
    AND CURRENT_TIMESTAMP BETWEEN d.start_date AND d.end_date -- Ensure discount is within its valid period
GROUP BY
    p.category_name;
```