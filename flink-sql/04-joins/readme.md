# Joins playground


## Confluent Flink examples

### 1- Compute the number of orders per customer per minute (non-overlapping window)

The marketplace.orders source table is:

```sql
TABLE `prod`.`marketplace`.`orders` (
  `order_id` VARCHAR(2147483647) NOT NULL,
  `customer_id` INT,
  `product_ids` ARRAY<BIGINT>,
  `price` DECIMAL(10, 2),
  `order_details` VARCHAR(2147483647),
  CONSTRAINT `PK_order_id` PRIMARY KEY (`order_id`) NOT ENFORCED
)
```

As we generate an aggregate per minute, there is no need to update record by customer_id. But to get a window aggregation we need window_start and window_end columns.

Create a table in append log so there is not need to have primary keys:

```sql
create table order_count 
as select 
  window_start,
  window_end,
  count(order_id) as cnt 
from table(tumble( table `prod`.`marketplace`.`orders`, descriptor(`$rowtime`), interval '1' minutes)) 
group by window_start, window_end, `customer_id`;
```

use EXPLAIN to understand the physical plan:

```sql
explain select ...
```

With a result as:

```sh
StreamPhysicalSink [7]
  +- StreamPhysicalCalc [6]
    +- StreamPhysicalGlobalWindowAggregate [5]
      +- StreamPhysicalExchange [4]
        +- StreamPhysicalLocalWindowAggregate [3]
          +- StreamPhysicalCalc [2]
            +- StreamPhysicalTableSourceScan [1]
```

If we need to have an upsert or retract table, we need a primary key, but the source column may be nullable, so we need to colasce the column to get default value:

```sql
create table order_count (
  primary key(customer_id) not enforced
) 
as select 
  window_start, 
  window_end,
  coalesce(customer_id, 1) as customer_id, 
  count(order_id) as cnt 
from table(tumble( table `prod`.`marketplace`.`orders`, descriptor(`$rowtime`), interval '1' minutes)) 
group by window_start, window_end, customer_id;
```

### 2- Create table to hold the number of orders per product per minute (non-overlapping window).

Need to join with the orders with the product table on the product_ids. The product table is defined as:

```sql
TABLE `prod`.`marketplace`.`products` (
  `product_id` BIGINT NOT NULL,
  `name` VARCHAR(2147483647),
  `brand_id` BIGINT,
  `vendor` VARCHAR(2147483647),
```

In the orders the column product_ids is an array of ids, so we need to use [unnest](https://docs.confluent.io/cloud/current/flink/reference/queries/joins.html#array-expansion) in the joon. The `cross join unnest()` returns a new row for each element in the given array.

The grouping needs to use the product_id.

Also it is a recommended practice to add the window_time as the rowtime of the new kafka record in the output topic.

```sql
create table order_counts as 
select 
  window_start,
  window_end,
  count(order_id) as cnt,
  window_time TIMESTAMP as $rowtime
from table(tumble( table `prod`.`marketplace`.`orders`, descriptor(`$rowtime`), interval '1' minutes)) 
cross join unnest(`product_ids`) as product (product_id)
group by window_start, window_end, window_time, product_id;
```

### 3- Create a materialized view/table that holds the average (physical) volume of products ordered per customer per minute (non overlapping window).

Product_details is 1 to 1 linked to the products table. The Dimension column is 3 values from a Row type. So to compute the volume we need to multiple each of the 3 dimensions.

The solution needs first to do the join to get the product detail for each product within the order. To get the product ids within the order, it uses the `cross join unnest`, then to get the product details, it uses a `left join`

See cc-3-avg-prod-volume-per-mn.sql.

```sql
CREATE TABLE order_volumes AS
WITH orders_with_details as (
  select o.order_id, 
  s.dimensions.length,
  s.dimensions.height,
  s.dimensions.width,
  o.`$rowtime`
  from orders o
  CROSS JOIN UNNEST(o.product_ids) AS p(id)
left join `product_details` FOR SYSTEM_TIME AS OF o.`$rowtime` s on s.`product_id` = p.`id`
)
SELECT
  AVG(
  CAST(SPLIT_INDEX(length, 'c', 0) AS DOUBLE)
  *
  CAST(SPLIT_INDEX(width, 'c', 0) AS DOUBLE)
  *
  CAST(SPLIT_INDEX(height, 'c', 0) AS DOUBLE)
  ) as avg_volume,
  window_time,
  o.order_id
FROM TABLE(
  TUMBLE(TABLE `orders_with_details`, DESCRIPTOR($rowtime), INTERVAL '1' MINUTE)
) o
GROUP BY window_start, window_end, window_time, o.order_id;
```

### 4- Create a materialized view/table that holds rolling average of the order value (last 10 orders) per customer.

### 5- Create a materialized view/table that holds total order value per order status at any given point in time.



```sql
select s.order_status, sum(o.price) as total from orders o
inner join order_status s on o.order_id = s.order_id
group by s.order_status;
```

The state is unbounded.

### 6- Create a materialized view/table that holds every order with the product and customer information as of the time when the order happened.

### 7- Create a materialized view/table that holds all up-to-date information related to an order. Whenever any of these tables is updated, I want the result table to be updated: 

* orders
* order_status
* products
* product_details
* customers
* categories
* brands

### 8- Find out if there is any correlation between between product category and the payment method used for the orders of these products? For this, you need to join orders to payments. 

### 9- Create a materialized view/table that holds for each customer_inquiries, the product information and order_status as of the time when the inquiry was created.

### 10- Create an “ACTIVE” alert and send it to a table called alerts as soon as the number of customer_inquiries in the last 30 minutes exceeded X. Also mark the alert as INACTIVE again as soon as the condition is not met anymore. 

### 11- Find customers who have ordered the same product twice without ordering another product in between. We want to send these customers a notification to see if that was a mistake before shipping the order.

### 12- Same as (XI), but this time we also want to alert if there are any other orders in between the two orders of the same product as long as they two orders of the same product happened within 30 days. 

### 13- Identify sessions via the clicks table. For each session, we are interested in the start, end and length of the session (in seconds) as well as the the list of URLs visited. 

### 14- Based on the output (XIV), send an alert if the average session length (rolling 5mins) drops significantly below the average session length (rolling 60mins). 

### 15- Implement a user-defined function GENERATE_SERIES(BIGINT from, BIGINT to) returning an ARRAY<BIGINT>. 

[See the product doc](https://docs.confluent.io/cloud/current/flink/how-to-guides/create-udf.html).

### 16- Improve the ValidateProductName 

Improve the ValidateProductName UDF to not only return whether product name is valid, but also a (n ideally structured) error with information why it is invalid, if it is invalid. The error shall be NULL if the product name is valid.

