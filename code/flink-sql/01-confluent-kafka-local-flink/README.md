# Local Flink with Local or Remote Kafka and some Flink SQL examples 

## Local Kafka Cluster - docker compose

Start the Confluent Platform using the docker compose in [deployment/docker](../../deployment/docker) folder using `cp-docker-compose.yaml`.

The data will be generated with open Source Flink "Faker" connector. 

### [optional] Use Kafka Connect Datagen connector

As an alternate we can use [Kafka Connector](https://github.com/confluentinc/kafka-connect-datagen) to generate random data using Faker.
Use the Docker image based on Kafka Connect with the [kafka-connect-datagen](https://hub.docker.com/r/cnfldemos/kafka-connect-datagen) plugin already installed.

* Use on Datagen Kafka connector configuration and post to the /connectors API:

```sh
curl -X POST -H "Content-Type: application/json" --data @datagen-config/shoe-products.json http://localhost:8083/connectors
```

## Local Flink binary execution 

Start one Flink **Job manager** and **Task manager**, using the `docker-compose.yaml` in this folder of this project. The docker file mounts the root folder in `/home`, so content of the data will be in `/home/data` 

* Create the Kafka Stream table

```sql
CREATE TABLE pageviews_kafka (
  `url` STRING,
  `user_id` STRING,
  `browser` STRING,
  `ts` TIMESTAMP(3)
) WITH (
  'connector' = 'kafka',
  'topic' = 'pageviews',
  'properties.group.id' = 'demoGroup',
  'scan.startup.mode' = 'earliest-offset',
  'properties.bootstrap.servers' = 'broker:29092',
  'properties.security.protocol' = 'PLAINTEXT',
  'value.format' = 'json',
  'sink.partitioner' = 'fixed'
);
```

* Create the table to generate records with FlinkFaker

```sql
CREATE TABLE `pageviews` (
  `url` STRING,
  `user_id` STRING,
  `browser` STRING,
  `ts` TIMESTAMP(3)
)
WITH (
  'connector' = 'faker',
  'rows-per-second' = '10',
  'fields.url.expression' = '/#{GreekPhilosopher.name}.html',
  'fields.user_id.expression' = '#{numerify ''user_##''}',
  'fields.browser.expression' = '#{Options.option ''chrome'', ''firefox'', ''safari'')}',
  'fields.ts.expression' =  '#{date.past ''5'',''1'',''SECONDS''}'
);
```

* Move records from the generated table to kafka topic

```sql
INSERT INTO pageviews_kafka SELECT * FROM pageviews;
```

## Remote connection to Kafka on CCloud

* Use confluent CLI  [See the Download page](https://docs.confluent.io/confluent-cli/current/install.html)

```sh
confluent login
confluent environment list
confluent environment use en-...
# if needed
confluent kafka cluster create my-cluster --cloud gcp --region us-central1 --type basic
confluent api-key create --resource <cluster-id> --description <cluster-name>-key -o json >  <cluster-name>-key.json
confluent kafka topic create pageviews --cluster <cluster-id>
confluent kafka cluster describe <cluster-id>
```

* Use the same local docker compose with just task manager, job manager and SQL client containers
* Create a table to connect to Kafka. Change the attributes with API_KEY, API_SECRETS and BOOTSTRAP_SERVER for the remote cluster

```sql
CREATE TABLE pageviews_kafka (
  `url` STRING,
  `user_id` STRING,
  `browser` STRING,
  `ts` TIMESTAMP(3)
) WITH (
  'connector' = 'kafka',
  'topic' = 'pageviews',
  'properties.group.id' = 'demoGroup',
  'scan.startup.mode' = 'earliest-offset',
  'properties.bootstrap.servers' = '${env:BOOTSTRAP_SERVER}',
  'properties.security.protocol' = 'SASL_SSL',
  'properties.sasl.mechanism' = 'PLAIN',
  'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.plain.PlainLoginModule required username="${env:API_KEY}" password="${env:API_SECRET}";',
  'value.format' = 'json',
  'sink.partitioner' = 'fixed'
);
```

* Add a table to generate records using the Flink sql client

```sql
CREATE TABLE `pageviews` (
  `url` STRING,
  `user_id` STRING,
  `browser` STRING,
  `ts` TIMESTAMP(3)
)
WITH (
  'connector' = 'faker',
  'rows-per-second' = '10',
  'fields.url.expression' = '/#{GreekPhilosopher.name}.html',
  'fields.user_id.expression' = '#{numerify ''user_##''}',
  'fields.browser.expression' = '#{Options.option ''chrome'', ''firefox'', ''safari'')}',
  'fields.ts.expression' =  '#{date.past ''5'',''1'',''SECONDS''}'
);
```

* Start sending generated data to kafka

```sql
INSERT INTO pageviews_kafka SELECT * FROM pageviews;
```

### Problems

10/08/24  the module org.apache.kafka.common.security.plain.PlainLoginModule is missing in job and task managers. We  need to add libraries. Verify if these are the good paths in the dockerfile of sql-client. This is not aligned with https://github.com/confluentinc/learn-apache-flink-101-exercises/blob/master/sql-client/Dockerfile


---
To sort out


1. Start Kafka cluster and create topics
   ```sh
   $KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/kraft/server.properties
   $KAFKA_HOME/bin/kafka-topics.sh --create --topic flink-input --bootstrap-server localhost:9092
   $KAFKA_HOME/bin/kafka-topics.sh --create --topic message-count --bootstrap-server localhost:9092
   ```

1. Use the Flink SQL Shell:
   ```sql
   $FLINK_HOME/bin/sql-client.sh --library $FLINK_HOME/sql-lib
   ```
      * Create a table using Kafka connector:
      ```sql
      CREATE TABLE flinkInput (
         `raw` STRING,
         `ts` TIMESTAMP(3) METADATA FROM 'timestamp'
      ) WITH (
         'connector' = 'kafka',
         'topic' = 'flink-input',
         'properties.bootstrap.servers' = 'localhost:9092',
         'properties.group.id' = 'j9rGroup',
         'scan.startup.mode' = 'earliest-offset',
         'format' = 'raw'
      );
      ```
      * Create an output table in a debezium format so we can see the before and after data:
      ```sql
      CREATE TABLE msgCount (
         `count` BIGINT NOT NULL
      ) WITH (
         'connector' = 'kafka',
         'topic' = 'message-count',
         'properties.bootstrap.servers' = 'localhost:9092',
         'properties.group.id' = 'j9rGroup',
         'scan.startup.mode' = 'earliest-offset',
         'format' = 'debezium-json'
      );
      ```
      * Make the simplest flink processing by counting the messages:
      ```sql
      INSERT INTO msgCount SELECT COUNT(*) as `count` FROM flinkInput;
      ```
      The result will look like:
      ```sh
      [INFO] Submitting SQL update statement to the cluster...
      [INFO] SQL update statement has been successfully submitted to the cluster:
      Job ID: 2be58d7f7f67c5362618b607da8265d7
      ```
      * Start a producer in one terminal
      ```sh
       bin/kafka-console-producer.sh --topic flink-input --bootstrap-server localhost:9092
      ```
      * Verify result in a second terminal
      ```sh
      bin/kafka-console-consumer.sh -topic message-count  --bootstrap-server localhost:9092
      ```
      The results will be a list of debezium records like
      ```sh
      {"before":null,"after":{"count":1},"op":"c"}
      {"before":{"count":1},"after":null,"op":"d"}
      {"before":null,"after":{"count":2},"op":"c"}
      {"before":{"count":2},"after":null,"op":"d"}
      {"before":null,"after":{"count":3},"op":"c"}
      {"before":{"count":3},"after":null,"op":"d"}
      {"before":null,"after":{"count":4},"op":"c"}
      ```