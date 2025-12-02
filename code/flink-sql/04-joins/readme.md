# Joins playground

## Understanding Basic Joins

[Based on the Confluent's blog: 'How to join a stream and a stream'](https://developer.confluent.io/tutorials/join-a-stream-to-a-stream/flinksql.html) but adapted for Confluent Cloud.

1. Create orders and shipments tables in CC, use cc_s2s_ddl_orders.sql and cc_s2__ddl_shipments.sql

    ```sh
    make create_orders
    make create_products
    make create_shipments
    ```

    The avro schemas are defined for the key and the value.

1. Add 3 products for 1 to 3 and all the orders ().
1. To do a first simple left join between orders and products: `make cc_s2s_order_product_join.sql` so all orders will have a product name added from the join. Let it runs.

The results looks like the following table, where the product_id 4 not being on the right side the generation is NULL

| id | product_id | product_name |
| --- | --- | --- |
| 1   | 1  |  Product-1 |
| 5   | 1  |  Product-1 |
| 6   | 1  |  Product-1 |
| 7   | 1  |  Product-1 |
| 2   | 2  |  Product-2 |
| 3   | 3  |  Product-3 |
| 4   | 3  |  Product-3 |
| 8   | 2  |  Product-2 |
| 9   | 4  | NULL |
| 10 | 3  |  Product-3 |

1. Add the 4th product with  `INSERT INTO products VALUES    ( 4,   'Product-4',    1692812175 );` Now the row 9 is modified with the `product-4`. As this table was not materialized. we can retry by doing a CTAS of the join (see `cc_s2s_ctas_join_1.sql`), the created topic has 1 partition and get the good results. It is an upsert table, which is mandatory as soon as there is left outer join in the statement. Flink must handle the scenario where left-side events do not have corresponding right-side events at the time of processing. The Upsert table allows Flink to store unmatched left records and update them when matching right records arrive later, ensuring all left records are included in the result, thus supporting the LEFT JOIN semantics effectively in a streaming context.
1. Next is to add an order without matching product: `INSERT INTO orders VALUES ( 11, 200.89, 'Art Vandelay', 1692812175, 5);`. The created event in the order_enriched topic is `1738379770426, {"id":11} {"id":11,"product_id":{"long":"5"},"product_name":null}`. Adding the missing product: `insert into products values ( 5,  'Product-5',    1692812190)` it will generate TWO records in the kafka topic: one delete and one new:

  ```sh
  Key       Value
  {"id":11} ""
  {"id":11} {"id":11,"product_id":{"long":"5"},"product_name": { "string": "Product-5"}}
  ```

  The left join emits the record without product name, while the join once the product arrived, generates 2 messages to support an upsert. 

1. Use insert shipments scripts in CC.
1. Implements an inner join between the orders and shipments. This kind of join only emits events when there’s a match on the criteria of both sides of the join. It also uses the INTERVAL function to perform an interval join, which also needs a sql timestamp to specify an addition join requirement that order and shipment occured within seven days of each other: See `cc_s2s_join-2.sql`. To make it persistent, meaning results will be in an output topic, use: `cc_s2s_ctas_join-2.sql` which creates 1 partition topic. 

  ```sql
  select ...
  ROM orders o inner join shipments s ON o.id = s.order_id
    AND TO_TIMESTAMP(FROM_UNIXTIME(s.ship_ts_raw))
     BETWEEN TO_TIMESTAMP(FROM_UNIXTIME(o.order_ts_raw))
     AND TO_TIMESTAMP(FROM_UNIXTIME(o.order_ts_raw))  + INTERVAL '7' HOURS;
  ```

The results will include only 8 records as record 9 and 10 has more than 7 hours difference. 


## Confluent Flink more advance problems

### 1- Compute the number of orders per customer per minute (non-overlapping window)

The `marketplace.orders` source table is:

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

