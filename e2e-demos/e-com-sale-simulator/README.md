# E-commerce rela-time analytics

This demonstration presents a real-time data processing with Kafka local cluster combined with Flink app used for real-time analytics.

**Context**: An online retail company wants to analyze customer behavior and sales performance in real-time. They need to track user actions, purchases, and inventory levels to make quick business decisions and optimize their operations.

*Data to generate:*

* User actions (page views, product clicks, add to cart events)
* Purchases
* Inventory updates

The Flink job consumes this data from the Kafka topic and performs various analyses, such as:

* Calculate real-time sales metrics (e.g., revenue per minute, top-selling products)
* Detect and alert on low inventory levels
* Analyze user behavior patterns (e.g., most viewed products, conversion rates)
* Implement a simple recommendation system based on user actions


The SQL client can be used to compute some aggregation on the sale events created by the `E-commerce simulator`. 

## Setup

To start the simulator using a Python virtual environment do:

```sh 
# under e2e-demos/e-com-sale-simulator
pip install -r requirements.txt
python simulator.py
```

The application sends events like the following:


```json
{'event_type': 'user_action', 
 'timestamp': '2024-09-04T15:24:59.450582', 
 'user_id': 'user5', 
 'action': 'add_to_cart', 
 'page': 'category', 
 'product': 'headphones'
}
```

* Use the [Kafdrop interface to verify the messages in the topic](http://localhost:9000/topic/ecommerce_events)
* Connect to SQL client container

    ```sh
    docker exec -ti sql-client bash
    # in the container shell, start sql cli
    ./sql-client.sh
    ```

* Define the user page view table:

    ```sql title="User page view on kafka stream"
    CREATE TABLE user_page_views (
        event_type STRING,
        user_id STRING,
        action STRING,
        page STRING,
        product STRING,
        timestamp_str STRING,        # (1)
        timestamp_sec TIMESTAMP(3),  # derived field
        WATERMARK FOR timestamp_sec AS TO_TIMESTAMP(timestamp_str, 'yyyy-MM-dd HH:mm:ss') - INTERVAL '5' SECOND
    ) WITH (
        'connector' = 'kafka',
        'topic' = 'ecommerce_events',
        'properties.bootstrap.servers' = 'kafka:29092',
        'properties.group.id' = 'sql-flink-grp-1',
        'properties.auto.offset.reset' = 'earliest',
        'format' = 'json'  
    );
    ```

    1. The event timestamp is a string created by the Kafka producer

**WATERMARK** statement is used to define a watermark strategy for handling event time in streaming applications. Watermarks are crucial for dealing with out-of-order events, allowing Flink to manage late arrivals and trigger processing based on event time rather than processing time. A watermark is a timestamp that indicates that no events with a timestamp earlier than the watermark will arrive. 

It is important to set the consumer properties like consumer group id, the offset reset strategy...

The following SQL statement is to count the number of page per user

```sql
SELECT 
    user_id, 
    page,
    COUNT(page) AS page_views 
FROM 
    user_page_views 
GROUP BY 
    user_id,
    page;
```

The results

![](./images/query_result.png)

## Run the simulator

* Start the Kafka cluster and Flink job manager and task manager
* Adjust the KAFKA_BOOTSTRAP_SERVERS, KAFKA_USER, KAFKA_PASSWORD, KAFKA_CERT environment variables as needed. To get those values from a local deployment using kubernetes:

```sh
kubectl describe kafka -n confluent
kubectl port-forward service/kafka 9092:9092 -n confluent
```
* Create the `ecommerce-events` topic

```sh
kubectl apply -f k8s/topics.yaml
```

* Start the simulator
```sh
python simulator.py
```

## Flink app

The Flink job sets up a Kafka consumer to read the data from the "ecommerce-events" topic. The FlinkKafkaConsumer is configured with the necessary Kafka properties, including the bootstrap servers and the consumer group. The data stream is then mapped to the EcommerceEvent class.

The EcommerceEventProcessor class may do the process logic like:

* Calculating real-time sales metrics (e.g., revenue per minute, top-selling products)
* Detecting and alerting on low inventory levels
* Analyzing user behavior patterns (e.g., most viewed products, conversion rates)
* Implementing a simple recommendation system based on user actions
