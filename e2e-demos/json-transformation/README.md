# Json transformation with Confluent Platform Flink

## Overview

This is a simple demo using Confluent Platform with Flink, or Confluent Cloud for Flink and Kafka to demonstrate a json schema mapping, with join and an aggregation using Flink SQL queries. 

The example is about a fictitious mover truck rental company, in 2190. This demonstration covers all the components to create and deploy for a Flink application consuming records from 2 Kafka topics and generating records to one topic.

The processing logic, we need to implement, has the following basic data pipeline architecture:

  ![](./docs/dsp.drawio.png)

The input are:

* Industrial vehicle rental events within `orders` kafka topic, 
* Human Job demand, which in the context of a Mover, a move demand, helping to move furniture,..

The jobs are related to a move `orders`, so the join key is the `OrderId`.

## Use Case

* Truck rental orders continuously arrive to the `raw-orders` kafka topic, while job demands are sent to `raw-jobs` topic. 

![](./src/demo-app/static/mover-truck-2100.png)
*Image generated with Google Gemini*

* The raw-orders json payload looks like:
    ```json
    {
      "OrderId": 123456,
      "Status": "Return",
      "Equipment": [
        {
          "ModelCode": "TK-01",
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
      "OrderType": "Move",
      "AssociatedContractId": null
    }
    ```

* The raw-job json is: (order_id is used to join to orders)
  ```json
  {
    "job_id": 1234567,
    "order_id": 123456, 
    "job_type": "LoadUnload",
    "job_status": "Completed",
    "rate_service_provider": "85.0000",
    "total_paid": "170.0000",
    "job_date_start": "2020-07-17",
    "job_completed_date": "2020-07-17",
    "job_entered_date": "2020-07-14",
    "job_last_modified_date": "2020-07-14",
    "service_provider_name": "ArizonaDream"
  }
  ```


* The goal of the first transformation is to take the raw source records and to build a JSON with nested structure: the `OrderDetails` which includes two main objects: the `EquipmentRentalDetails` and the `MovingHelpDetails`:
  ```json
  {
      "OrderDetails": {
         "OrderId": 396404719,
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
        ],
        "MovingHelpDetails": null
      },
      ...
  }
  ```

* The second real-time processing is doing a join with the `raw_jobs` topic, to enrich the `OrderDetails.MovingHelpDetails` with the jobs information:
  ```json
      "MovingHelpDetails": [
        {
            "job_id": 1234567,
            "job_type": "LoadUnload",
            "job_status": "Completed",
            "rate_service_provider": "85.0000",
            "total_paid": "170.0000",
            "job_date_start": "2020-07-17",
            "job_completed_date": "2020-07-17",
            "job_entered_date": "2020-07-14",
            "job_last_modified_date": "2020-07-14",
            "service_provider_name": "ArizonaDream"
          }
      ]
  ```

* Finally the equipment rental details can be used to compute aggregations and business analytics data products.

## Architecture

The components involved in this demonstration are depicted in the following figure:

![](./docs/components.drawio.png)

* Confluent Platform with Kafka Brokers, Schema registry and Kafka Connectors cluster (not in this demo)
* Different topics to persist events: raw-orders, raw-jobs, and order-details topics
* Confluent Manager for Flink to manage Flink Environments, Compute Pools, Flink Applications
* Schema Registry for schema governance
* Flink Applications in the form of TableAPI application with SQL scripts or SQL statements created with Flink SQL shell.
* WebApp to support the demonstation and to produce the different event types.

### Explanations for Flink Environment, Compute pool...

The Flink application(s), and the record producer Webapp are deployed under the `rental` namespace. The CMF, CFK, and FKO operators are deployed within the `confluent` namespace. To be able to deploy cross namespace multiple configurations need to be done.

* FKO needs to support `rental` namespace, this is done using the helm deployment. (Makefile `deployment/k8s/` with target `install_upgrade_fko`)
* The service account managing resources in the context of those operators (`flink` service account) needs to be able to  get resource `namespaces` in API group in the application namespace(`rental`). For that ensure the following role binding:
  ```yaml
  kind: RoleBinding
  apiVersion: rbac.authorization.k8s.io/v1
  metadata:
    namespace: rental
    name: flink-confluent-cross-ns-rb
  subjects:
  - kind: ServiceAccount
    namespace: confluent
    name: flink
  roleRef:
    kind: Role
    name: flink-sa-r
    apiGroup: rbac.authorization.k8s.io
  ```
  which are defined in `k8s/rbac.yaml` 

---

## Demonstration Script

The code and/or instructions are NOT intended for production usage.

### Prerequisites

* Clone this repository and work in the `flink-studies/e2e-demos/json-transformation` folder.
* We assume a Kubernetes cluster is up and running with the Confluent Platform and Confluent Manager for Flink deployed. Use at least version 8.1.x. See [deployments readme and Makefiles](https://github.com/jbcodeforce/flink-studies/tree/master/deployment/k8s) for the platform deployment.
* The project uses `make` tool
* Look at the available demonstration targets:
    ```
    make help
    ```

### CMF Setup

The Kubernetes deployment is done using Colima VM and Confluent Platform. [See the CP deployment readme](../../deployment/k8s/cp-flink/README.md) and use the makefile in `deployment/k8s/cp-flink` to start Colima, deploy Confluent Platform, with Confluent Manager for Flink and then verify Flink and Kafka are running. 

* Make sure the CMF REST API is accessible on localhost:
  ```sh
  make verify_cmf
  make port_forward_cmf
  ```

### Build and Deploy the components

* All the demonstration components are deployed under the `rental` namespace in Kubernetes, and will have the following metadata:
  ```yaml
  metadata:
    labels:
      name: rental-demo
      app: json-xform
      component: <specific_name>
  ```

* Build and deploy all, from this `json-transformation` folder
  ```sh
  make build_all
  make deploy_all
  ```

*Remarks* all the components can be built individually using the Makefile under each component folder under `src`. Therefore in each folder a call to `make build` and a `make deploy` will build the component, the docker image, and then deploy to k8s under the `rental` namespace.

* Verify all components run successfully
  ```sh
  make status_all 
  ```

* Start the Demo Web App:
  ```sh
  make open_demo_web_page
  ```

* [optional] Start the CP Console browser. It can be accessed via the Demo console too.
  ```sh
  make open_cp_console
  ```

### Upgrade to a new CP Flink version

* See [deployment/k8s/cfk](../../deployment/k8s/cfk/README.md) for Confluent Platform upgrade
* See [deployment/k8s/cmf](../../deployment/k8s/cmf/README.md) for Confluent Manager for Flink upgrade
* [Get the cp-flink tag version from dockerhub](https://hub.docker.com/r/confluentinc/cp-flink/tags) modify the version in [Dockerfile](./src/cp-flink/table_api/Dockerfile) and update the matching `flink.version` in the [pom.xml for the table api code](./src/cp-flink/table_api/pom.xml)
* Modify flink sql image version in [compute-pool](./k8s/compute-pool-cmf.json)
* Change the version number in the [flink_application](./src/cp-flink/k8s/flink_application.json) see [product documentation](https://docs.confluent.io/platform/current/flink/jobs/applications/create.html).

### Demonstration from the user interface

The demonstration user interface includes the form and controls to drive the demonstration, the scripts is inside the Demo Description section

![](./docs/demo-ui.png)

1. Create input data in the raw order topics: 
  **Select Message Type**
  📦 Order Records: E-commerce order data
  ![](./docs/orders_created.png)


1. Validate orders records are in topic using the CP Console too:
  ![](./docs/raw_orders_in_topic.png)

1. Same for jobs, with "💼 Job Records: Job posting data"
  ![](./docs/jobs_created.png)

1. In the CP Console, raw-job topic, messages should be present (be sure to select from beginning).
  ![](./docs/raw_jobs_in_topic.png)

### 🌐 Web Interface Usage

* **Step 1: Select Message Type**
  * 📦 Order Records: Truck Rental portal order data
  * 💼 Job Records: Job posting data
  * 🛠️ Custom JSON: Your own JSON payload

* **Step 2: Configure Production**
  * Topic: Kafka topic name (with smart auto-suggestions)
  * Count: Number of records to produce (1-1000)
  * Custom JSON: Rich editor for custom payloads

* **Step 3: Monitor Progress**
  * Real-time record producer job status updates
  * Automatic polling for completion
  * Success/error notifications
  * Producer job history tracking

### Flink SQL processing

There are multiple approaches for the implementation. The easiest one is to tune the SQL queries with the Flink SQL shell. For production, the approach is to use a jar packaging with the Java code which may use DataStream or TableAPI.

For Confluent Manager for Flink, the SQL feature is in preview (as of 07/2025). The elements to defined for SQL processing are the same as in Confluent Cloud for Flink with Environment, Compute Pools, and Catalog. 

The [k8s folder](https://github.com/jbcodeforce/flink-studies/blob/master/e2e-demos/k8s/) includes the following nanifests:

| Manifest | Description | Deployment |
| --- | --- | --- |
| FlinkEnvironment - name: dev-rental| Environment to define common resources | `make create_environment` |
| ComputePool - name: rental-pool | Compute pool to define configuration for app | `make create_compute_pool` |


Recall the relationship between those elements are illustrated in the figure below:

![](https://github.com/jbcodeforce/flink-studies/blob/master/docs/coding/diagrams/cmf-cr.drawio.png)

The approach:

1. Be sure to be unlogged of confluent cloud session when using the confluent cli to the platform:
    ```sh
    confluent login
    confluent logout
    ```
1. Be sure port forward to CMF REST api is set up: `make expose-services` or specifically: `make port_forward_cmf`

The following steps should have been run with the previous execution of `make build_all`. In case of they may be executed sequentially to demonstrate deployment steps:
1. Create the environment with: `make create_environment`
1. Set env variables:
    ```sh
    export ENV_NAME=dev-rental
    export CONFLUENT_CMF_URL=http://localhost:8084
    ``` 
1. List environment
  ```sh
  confluent flink environment list
  # or using curl
  curl -X GET $CONFLUENT_CMF_URL/cmf/api/v1/environments
  ```
1. View environment detail:
  ```sh
  confluent flink environment describe dev-rental
  # or using curl
  curl -X GET $CONFLUENT_CMF_URL/cmf/api/v1/environments/dev-rental
  ```
1. List existing compute pools in an environment
  ```sh
  confluent flink compute-pool list --environment $ENV_NAME
  # using curl
  curl -X GET $CONFLUENT_CMF_URL/cmf/api/v1/environments/dev-rental/compute-pools
  ```

1. Create the compute pool with: 
    ```sh
    make create_compute_pool
    # same as 
    confluent flink compute-pool create k8s/compute_pool.yaml --environment $ENV_NAME 
    ```
1. Verify existing compute pools:
  ```sh
  confluent flink compute-pool list --environment $ENV_NAME
  confluent flink compute-pool describe rental-pool  --environment $ENV_NAME
  # using curl
  curl -X GET $CONFLUENT_CMF_URL/cmf/api/v1/environments/dev-rental/compute-pools/rental-pool
  ```
1. Create Kafka secret so flink can access kafka topic
    ```sh
    make create_secret
    # using curl
    curl -X POST -H "Content-Type: application/json" -v -d @k8s/kafka_secrets.json $(CONFLUENT_CMF_URL)/cmf/api/v1/secrets
    make map_secret
    ```
1. Create SQL Catalog
    ```sh
    make create_catalog
    ```

#### Flink SQL Shell

During query development the shell is the most efficient to write the complex query incrementally. Ensure the cmf service is exposed via a port forward, using `make expose_services` in this folder.

```sh
cd src/cp-flink
make start_flink_shell
```

* Within the shell verify catalog access and set the database to use:
  ```sql
  show catalogs;
  use catalog rental;
  use rentaldb;
  show tables;
  ```
* `show tables;` should return the raw-orders and raw-jobs tables.

1. Verify content for the tables we need to join
  ```sql
  select * from `raw-jobs`;
  select * from `raw-orders`;
  ```

1. Implement the json transformation, filtering, joins... see [the dedicated section below](#the-flink-sql-processing)

???+ info "Other useful commands"
  The following commands should be available soon in CP Flink:
  ```sql
  show create table `raw-jobs`;
  explain select .... -- your query
  ```

### Clean up

* Under the current folder.
```sh
make undeploy_all
```

---
## Code explanation

### Project structure

The approach is to keep component in separate folder under `src`, with makefile to build, deploy, get the status of the running pods. Each with its own k8s manifests.

| Folder | Content |
| --- | --- |
| **k8s** | Makefile and common kubernetes elements of the demonstrations. Common to all components, like namespace and config map |
| **src/cp-flink** | Flink statemens as Table API code or pure SQLs |
| **docs** | Some diagrams |
| **src/producer** | Web App and CLI to produce demonstration records to the  `raw-orders` and `raw-jobs` | 
| **src/schemas** | Json schema definitions to be deployed by schema registry |
| **src/cc-flink** | Equivalent Flink SQLs for Confluent Cloud Flink - Start earlier to  code SQL logic. see the [README.md](./src/cc-flink/README.md) for instructions|

The `k8s` folder includes the configuration to create schemas and topics for the raw input data: `jobs` and `orders` and the `order-details` topic and schema. When deploying to Kubernetes, the topic and schema are defined as config maps. The following diagram illustrates the relationships with those k8s elements:

![](./docs/k8s_cp_elements.drawio.png)

The dark blue represents application specific elements, while the light blue elements represent reusable, cross applications, components.

The makefile under this folder, helps to deploy those elements to the Confluent Platform.

### Producer Features

- Support for jobs and orders records creation, with custom JSON record
- Type-safe record definitions with validation using Pydantic
- Command-line interface for easy testing and automation
- Built-in callback handling for message delivery confirmation
- Include a FastAPI Application (api_server.py) which supports the following REST API:
    * POST /produce: Produce predefined record types (job/order), with configurable count
    * POST /produce/custom: Produce custom JSON payloads
    * Health Checks: Dependency verification and service status

* Background Processing: Asynchronous job execution using FastAPI BackgroundTasks

The following figure illustrates the different deployment model:

![](./docs/kafka_producer_deployment.png)

* CLI based usage examples, to send 5 records to a specific topic
  ```sh
  uv run python kafka_json_producer.py --record-type order --topic raw-orders --count 5
  # 
  uv run python kafka_json_producer.py --record-type job --topic raw-jobs --count 5
  ```

* Webapp based usage: the following command is for development, as the final deployment should be via Kubernetes.  
  ```sh
  uv run api_server.py
  ```

#### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `KAFKA_BOOTSTRAP_SERVERS` | `kafka.confluent.:9071` | Kafka broker addresses |
| `KAFKA_TOPIC` | `test-records` | Default topic name |
| `KAFKA_USER` | _(empty)_ | SASL username |
| `KAFKA_PASSWORD` | _(empty)_ | SASL password |
| `KAFKA_SECURITY_PROTOCOL` | `PLAINTEXT` | Security protocol |
| `KAFKA_SASL_MECHANISM` | `PLAIN` | SASL mechanism |
| `KAFKA_CERT` | _(empty)_ | SSL certificate path |

Those environment variables are defined in `k8s/kafka_client_cm.yaml`.

### The Flink SQL processing

Defining JSON objects as sink, involves defining the `value.format` property for the tables created:

```sql
    'value.format' = 'json-registry',
```

#### raw_job mapping

To start the development of the SQL code, we use the simple raw_job as it is a flat input structure. The target one element that will be an array of json objects. This first version of table definition will be defined as:

```sql
create table dim_jobs (
  MovingHelpDetails ARRAY<ROW<
    job_id BIGINT,
    job_type STRING,
    job_status STRING,
    rate_service_provider STRING,
    total_paid DECIMAL(10,2),
    job_date_start STRING,
    job_completed_date STRING,
    job_entered_date STRING,
    job_last_modified_date STRING,
    service_provider_name STRING
  >>) WITH (
    'value.avro-registry.schema-context' = '.dev',
   'kafka.retention.time' = '0',
    'changelog.mode' = 'append',
   'kafka.cleanup-policy'= 'compact',
   'scan.bounded.mode' = 'unbounded',
   'scan.startup.mode' = 'earliest-offset',
   'value.fields-include' = 'all',
    'value.format' = 'json-registry',
    'value.fields-include' = 'all'
);
```

If we want to map raw_jobs to the dim_jobs

```sql
insert into dim_jobs (MovingHelpDetails)  
  SELECT   
    ARRAY[ 
      ROW(
        j.job_id, 
        j.job_type,
        j.job_status,
        j.rate_service_provider,
        j.total_paid,
        j.job_date_start,
       j.job_completed_date,
       j.job_entered_date,
      j.job_last_modified_date,
      j.service_provider_name)
    ] 
  from raw_jobs j;
```

and the results are as expected:

```json
{
  "MovingHelpDetails": [
    {
      "job_id": 1005,
      "job_type": "cleaning",
      "job_status": "cancelled",
      "rate_service_provider": "hourly",
      "total_paid": 0,
      "job_date_start": "2024-01-18 14:00:00",
      "job_completed_date": "",
      "job_entered_date": "2024-01-14 09:20:00",
      "job_last_modified_date": "2024-01-17 16:45:00",
      "service_provider_name": "QuickMover"
    }
  ]
}
```

#### raw_order mapping

The OrderDetails is build in the ddl.order_details.sql

```sql
create table order_details (
   OrderId BIGINT NOT NULL PRIMARY KEY not enforced,
   EquipmentRentalDetails ARRAY<ROW<
      OrderId BIGINT,
      Status STRING,
      Equipment ARRAY<ROW<
        ModelCode STRING,
        Rate STRING
      >>,
      TotalPaid DECIMAL(10,2),
      Type STRING,
      Coverage STRING,
      Itinerary ROW<
        PickupDate TIMESTAMP(3),
        DropoffDate TIMESTAMP(3),
        PickupLocation STRING,
        DropoffLocation STRING
      >,
      OrderType STRING,
      AssociatedContractId BIGINT>>,
  MovingHelpDetails ARRAY<ROW<
    job_id BIGINT,
    job_type STRING,
    job_status STRING,
    rate_service_provider STRING,
    total_paid DECIMAL(10,2),
    job_date_start STRING,
    job_completed_date STRING,
    job_entered_date STRING,
    job_last_modified_date STRING,
    service_provider_name STRING
  >>
  ) distributed by hash(OrderId) into 1 buckets WITH ( 
   'value.avro-registry.schema-context' = '.dev',
   'kafka.retention.time' = '0',
    'changelog.mode' = 'append',
   'scan.bounded.mode' = 'unbounded',
   'scan.startup.mode' = 'earliest-offset',
   'value.fields-include' = 'all',
    'value.format' = 'json-registry',
    'value.fields-include' = 'all'
);
```

```sql
insert into dim_orders(OrderId, EquipmentRentalDetails)
SELECT
  OrderId,
  ARRAY[
    row(
     OrderId,
  Status,
  TotalPaid,
  `Type`,
  Coverage,
  OrderType,
  CAST(AssociatedContractId as BIGINT)
    )
  ]
from raw_orders
```


#### Combining

#### 1. Direct Nested Access

The 
```sql
SELECT OrderDetails.EquipmentRentalDetails[1].OrderId 
FROM OrderDetails;
```

#### 2. Array Unnesting (Recommended)
```sql
SELECT rental_detail.OrderId, equipment_item.ModelCode
FROM OrderDetails
CROSS JOIN UNNEST(OrderDetails.EquipmentRentalDetails) AS t(rental_detail)
CROSS JOIN UNNEST(rental_detail.Equipment) AS e(equipment_item);
```

#### 3. Flattened Output
```sql
INSERT INTO OrderDetails_Flat
SELECT 
  rental_detail.OrderId,
  rental_detail.Status,
  equipment_item.ModelCode,
  equipment_item.Rate,
  rental_detail.TotalPaid,
  rental_detail.Itinerary.PickupDate,
  rental_detail.Itinerary.DropoffDate
FROM OrderDetails
CROSS JOIN UNNEST(OrderDetails.EquipmentRentalDetails) AS t(rental_detail)
CROSS JOIN UNNEST(rental_detail.Equipment) AS e(equipment_item);
```

### Confluent documentation and limitations

* [Interactive SQL Shell](https://docs.confluent.io/platform/current/flink/jobs/sql-statements/use-interactive-shell.html)
* [Current limitations](https://docs.confluent.io/platform/current/flink/jobs/sql-statements/features-support.html#limitations)


## Troubleshouting

* The flinkApplication status: `make status` from the `cp-flink` folder
* Access the Flink Web UI: `make flink_ui`
* Look at the log of the CMF pod:
  ```sh
  # get the pod id
  kubeclt logs confluent-manager-for-apache-flink-75b97474c9-6k92v -n confluent
  ```

### Multiple planner factory

Error: "Multiple factories for identifier 'default' that implement 'org.apache.flink.table.delegation.ExecutorFactory' 
   found in the classpath. Ambiguous factory classes are: io.confluent.flink.plugin.internal.ConfluentExecutorFactory"

**Reason:** This typically happens when both the Confluent Flink Table API plugin and the default Flink planner are included as dependencies,

**Solution:**: Be sure to do not have the CC FLink plugin in the pom.xml, something like:
  ```xml
        <dependency>
            <groupId>io.confluent.flink</groupId>
            <artifactId>confluent-flink-table-api-java-plugin</artifactId>
            <version>${confluent-plugin.version}</version>
        </dependency>
  ```

### Invalid table name: raw-orders

Most likely the name of the table should include the catalog and database name. One way to verify this is to use the SQL shell.

### Could not delete environment

Need to remove compute pools and Flink statements. The scripts `delete_statements.sh` use the confluent cli to remove all statements.

### KafkaCatalog not found

Do not use kubectl to create Kafka Catalog but confluent cli.

### C3 console cannot connect to Confluent Manager for Apache Flink.

