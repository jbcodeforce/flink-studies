# Simple Proof Of Concept for Confluent Platform Flink

This is a simple demo to use Confluent Platform with Flink to demonstrate a json schema mapping, a join and an aggregation.

The input is an industrial vehicle rental event, with an example of order in data/order_detail.json. The second input is a job demand, which in the context of a Mover, a move demand.

## Use Case

* Rental orders continuously arrive to the raw-contracts kafka topic, while job demands are sent to raw-jobs. 

* The source records need to be transformed as JSON with nested structure:
```json
{
    "OrderDetails": {
      "EquipmentRentalDetails": [
        {
          "OrderId": 396404719,
          "Status": "Return",
          "Equipment": [
            {
              "ModelCode": "HO",
              "Rate": "34.95"
            }
          ],
          "TotalPaid": 37.4,
          "Type": "InTown",
          "Coverage": null,
          "Itinerary": {
            "PickupDate": "2020-09-21T18:14:08.000Z",
            "DropoffDate": "2020-09-21T20:47:42.000Z",
            "PickupLocation": "41260",
            "DropoffLocation": "41260"
          },
          "OrderType": "Umove",
          "AssociatedContractId": null
        }
      ]
    },
    "MovingHelpDetails": null
}
```

## Code explanations

The cp-flink folder includes the configuration to create schemas and topics for the raw input data: jobs and orders. The makefile helps to deploy those elements to the Confluent Platform.

The Kafka order and job records producers code is under producer folder.

### Producer Features

- Support for jobs and orders records, and custom JSON
- Type-safe record definitions with validation
- Command-line interface for easy testing and automation
- Built-in callback handling for message delivery confirmation
- Include a FastAPI Application (api_server.py) which supports the following REST API:
  * POST /produce: Produce predefined record types (job/ordeith configurable count
  * POST /produce/custom: Produce custom JSON payloads
  * Health Checks: Dependency verification and service status

* Background Processing: Asynchronous job execution using FastAPI BackgroundTasks

The following figure illustrates the different deployment model:

![](./docs/kafka_producer_deployment.png)

* CLI based usage examples:
  ```sh
  python kafka_json_producer.py --record-type order --topic raw-orders --count 5
  # 
  python kafka_json_producer.py --record-type job --topic raw-jobs --count 5
  ```

* Webapp based usage: the command is just during development, as the final deployment should be via kubernetes with 
  ```sh
  uv run api_server.py
  ```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `KAFKA_BOOTSTRAP_SERVERS` | `kafka.confluent.:9071` | Kafka broker addresses |
| `KAFKA_TOPIC` | `test-records` | Default topic name |
| `KAFKA_USER` | _(empty)_ | SASL username |
| `KAFKA_PASSWORD` | _(empty)_ | SASL password |
| `KAFKA_SECURITY_PROTOCOL` | `PLAINTEXT` | Security protocol |
| `KAFKA_SASL_MECHANISM` | `PLAIN` | SASL mechanism |
| `KAFKA_CERT` | _(empty)_ | SSL certificate path |

### Producers Deployment

The cp-flink folder includes config_map and Kubernetes job manifests to start the producer to produce records for jobs and orders to the raw-orders and raw-jobs topics.

* Deploy config map and orders as kuberneted job to create 10 orders
  ```sh
  make create_kafka_client_cm
  make deploy_order_producer
  ```

* Deploy job producer for 10 jobs
  ```sh
  make deploy_job_producer
  ```

* Deploy the WebApp
  ```sh
  # Deploy the API
  make deploy_producer_api
  # Setup port forwarding  
  make port_forward_producer_api
  # Test the API
  make test_api_health
  ```

## CMF Setup

Be sure to have Confluent Platform deployed on kubernetes ([See this readme](../../deployment/k8s/cp-flink/README.md)) and use the makefile in deployment/k8s/cp-flink to start Colima, and then verify flink and Kafka are running. 

* Make sure the CMF REST API is accessible on localhost:
```sh
make verify_cp_cfk
make verify_cmf
make port_forward_cmf
```

The cp-flink folder in this json-transformation project, includes a makefile to manage port-forwarding, create topics...

* Define orders and jobs topic, json schema using config map and schema registry entry
    ```sh
    make create_topics
    make create_cms
    make create_schemas
    ```

* Validate we can see the catalog and table using Flink SQL shell
    ```sh
    make start_flink_shell
    ```

### Flink Shell common commands

```sh
show catalogs;
use catalog demo-cat;
show databases;
use cluster-1;
show tables;
```

* `show tables;` should return the raw-orders and raw-jobs tables.

### To do

* [x] Define schema using config map and assess if CM can be loading schema from file
* [x] Write producer of raw-orders and raw-orders.
* [x] Use k8s job deployment to deploy to k8s with config map to set some env-variable.
* [ ] Define sql to change json schema for the orders

### Issues to fix

* [ ] Confluent Console connection error with port forwarding

## Demonstration

### Create input data in the two raw topics

* Deploy web interface + CLI producers:
```bash
make demo_web  # Complete setup with web access
```

* Access to the web interface for interactive control:
```bash
make open_web_ui
```

### **Interactive Documentation**
- 🌐 **Web Interface**: `http://localhost:8080/` - User-friendly form interface
- 📚 **Swagger UI**: `http://localhost:8080/docs` - Interactive API testing
- 📖 **ReDoc**: `http://localhost:8080/redoc` - Beautiful API documentation  


### 🌐 Web Interface Usage

* **Step 1: Select Message Type**
  * 📦 Order Records: E-commerce order data
  * 💼 Job Records: Job posting data
  * 🛠️ Custom JSON: Your own JSON payload

* **Step 2: Configure Production**
  * Topic: Kafka topic name (with smart auto-suggestions)
  * Count: Number of records to produce (1-1000)
  * Custom JSON: Rich editor for custom payloads

* **Step 3: Monitor Progress**
  * Real-time job status updates
  * Automatic polling for completion
  * Success/error notifications
  * Job history tracking

### **Quick Make Commands**
```bash
# Web Interface - Direct Access (RECOMMENDED)
make demo_web_direct        # Complete setup + direct localhost access
make open_web_ui_nodeport   # Open web interface (NodePort)
make open_swagger_nodeport  # Open Swagger UI (NodePort)  
make open_redoc_nodeport    # Open ReDoc (NodePort)

# Web Interface - Port Forward Access
make demo_web               # Complete setup + port-forward access
make open_web_ui           # Open web interface (port-forward)
make open_swagger          # Open Swagger UI (port-forward)
make open_redoc            # Open ReDoc (port-forward)

# Deployment & Status
make deploy_producer_api   # Deploy API pod
make status_producers      # Check all producer status (shows access URLs)

# Testing - Direct Access
make test_api_health_nodeport       # Test API health (NodePort)
make test_api_produce_orders_nodeport  # Test order production (NodePort)
make test_api_produce_jobs_nodeport    # Test job production (NodePort)

# Testing - Port Forward Access  
make test_api_health       # Test API health (port-forward)
make test_api_produce_orders  # Test order production (port-forward)
make test_api_produce_jobs    # Test job production (port-forward)

# Management
make cleanup_demo          # Remove all components
```

### Flink SQL processing

* The first transformation script is to 
## CCF Setup