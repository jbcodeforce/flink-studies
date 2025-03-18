# E-commerce real-time analytics

This demonstration presents a real-time data processing with a local Kafka cluster combined with Flink app used for real-time analytics.

**Context**: An online retail company wants to analyze customer behavior and sales performance in real-time. They need to track user actions, purchases, and inventory levels to make quick business decisions and optimize their operations.

*Data to generate:*

* User actions (page views, product clicks, add to cart events)
* Purchases
* Inventory updates

The Flink job consumes this data from the Kafka topic and performs various analysis, such as:

* Calculate real-time sales metrics (e.g., revenue per minute, top-selling products)
* Detect and alert on low inventory levels
* Analyze user behavior patterns (e.g., most viewed products, conversion rates)
* Implement a simple recommendation system based on user actions


The SQL client can be used to compute some aggregation on the sale events created by the `E-commerce simulator`. 

## Setup

* If not done  yet, go to the k8s deployment for CP for Flink and the Confluent Platform deployment [here](../../deployment/k8s/README.md) and use the makefile to deploy all the needed components.
* Once Kafka runs, deploy the 3 topics needed for the demo: `kubectl apply -f k8s/topics.yaml`.
* Expose Kafka bootstrap endpoint via port-forward

```
kubectl port-forward svc/kafka 9092:9092 -n confluent
```

* Expose the Confluent Managed Flink URL: `make port-forward` 
* Package and deploy the Flink App: 

```sh
make build
make create_flink_app
```

## The Flink Application

The Flink job sets up a Kafka consumer to read the data from the "ecommerce.purchase" topic. The FlinkKafkaConsumer is configured with the necessary Kafka properties, including the bootstrap servers and the consumer group. The data stream is then mapped to the EcommerceEvent class.

The EcommerceEventProcessor class may do the process logic like:

* Calculating real-time sales metrics (e.g., revenue per minute, top-selling products)
* Detecting and alerting on low inventory levels
* Analyzing user behavior patterns (e.g., most viewed products, conversion rates)
* Implementing a simple recommendation system based on user actions

### First approach: use enrichment with a simple join

Enrich the purchase from the product table

```
```

### Unit tests

The unit tests use the Flink MiniCluster extension. 

## Start the simulator

To start the simulator using a Python virtual environment do:

```sh 
# under e2e-demos/e-com-sale
pip install -r requirements.txt
# Be sure the bootstrap URL is expose via port-forward
kubectl port-forward svc/kafka 9092:9092 -n confluent
# Create the topics
python simulator.py
```

The application sends three type of event: user-action, purchase, or inventory_update like the following:

```json
{'event_type': 'user_action', 
 'timestamp': '2024-09-04T15:24:59.450582', 
 'user_id': 'user5', 
 'action': 'add_to_cart', 
 'page': 'category', 
 'product': 'headphones'
}
```

Each event type will be in 3 different topics.

* Use the [Kafbat UI interface to verify the messages in the topic](http://localhost:9000/ui/clusters/kafka/all-topics/ecommerce.inventory)
