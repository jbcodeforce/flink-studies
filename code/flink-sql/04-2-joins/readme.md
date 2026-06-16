# Joins playground


### 3- Create a materialized view/table that holds the average (physical) volume of products ordered per customer per minute (non overlapping window).

Product_details is 1 to 1 linked to the products table. The Dimension column is 3 values from a Row type. So to compute the volume we need to multiple each of the 3 dimensions.

The solution needs first to do the join to get the product detail for each product within the order. To get the product ids within the order, it uses the `cross join unnest`, then to get the product details, it uses a `left join`

See [cc-3-avg-prod-volume-per-mn.sql](./cc/cc-3-avg-prod-volume-per-mn.sql).

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

## Data Skew

[See problem and solution statements](https://jbcodeforce.github.io/flink-studies/concepts/#data-skew) and the demo code in the [./data_skew/](./data_skew/) folder.