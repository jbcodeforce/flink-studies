# Flink and Kafka and some SQL streaming demo

Start one Flink **Job manager** and **Task manager**, using the `kafka-docker-compose.yaml` or the `confluent-flink-dc.yaml` in deployment-local folder of this project. The docker file mounts the root folder in `/home`, so content of the data will be in `/home/flink-sql-demos` 

## Local Flink execution 

* Start the confluent kafka cluster with the 3 Flink containers: 

```sql
docker compose -f confluent-flink-dc.yaml up -d
```

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

* Move records from generated table to kafka topic

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

* Use the local docker compose with just task manager, job manager and SQL client containers
* Create a table to connect to Kafka Streams

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

* Add a table to generate records

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

10/08/24  the module org.apache.kafka.common.security.plain.PlainLoginModule is missing in job and task managers. need to add libraries some how verify if these are the good paths in the dockerfile of sql-client. not aligned with https://github.com/confluentinc/learn-apache-flink-101-exercises/blob/master/sql-client/Dockerfile

