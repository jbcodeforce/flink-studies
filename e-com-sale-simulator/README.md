# E-commerce rela-time analytics

This demonstration, is to presnet a real-time data processing with Kafka combine with Flink analytics capabilities.

An online retail company wants to analyze customer behavior and sales performance in real-time. They need to track user actions, purchases, and inventory levels to make quick business decisions and optimize their operations.

Data to generate:

* User actions (page views, product clicks, add to cart)
* Purchases
* Inventory updates

The Flink job consumes this data from the Kafka topic and performs various analyses, such as:

* Calculate real-time sales metrics (e.g., revenue per minute, top-selling products)
* Detect and alert on low inventory levels
* Analyze user behavior patterns (e.g., most viewed products, conversion rates)
* Implement a simple recommendation system based on user actions

## Run the simulator

* Start the Kafka cluster and Flink job manager and task manager
* Adjust the KAFKA_BROKER and KAFKA_TOPIC environment variables if needed

```sh
python simulator.py
```

## Flink app

The Flink job sets up a Kafka consumer to read the data from the "ecommerce_events" topic. The FlinkKafkaConsumer is configured with the necessary Kafka properties, including the bootstrap servers and the consumer group. The data stream is then mapped to the EcommerceEvent class.

The EcommerceEventProcessor class may do the process logic like:

* Calculating real-time sales metrics (e.g., revenue per minute, top-selling products)
* Detecting and alerting on low inventory levels
* Analyzing user behavior patterns (e.g., most viewed products, conversion rates)
* Implementing a simple recommendation system based on user actions
