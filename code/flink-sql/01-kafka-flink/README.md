# Local Flink with Local or Remote Kafka and some Flink SQL examples 

## Goal

Getting started on running Flink and Apache OSS locally, or Confluent Platform Flink and Kafka on local k8s, or Flink OSS local with Confluent Cloud Kafka. 

Following configurations are addressed:

* Docker compose with Flink and Kafka OSS
* Apache Flink and Apache Kafka binary on local disk
* Confluent Platform


## Docker compose with Kafka latest image and flink 1.20

Folder kafka-flink-docker: The Docker Compose above directly starts the Kafka kraft broker image, and flink 1.20
with the flink-sql-connector-kafka jar in the connectors folder.

* Create topics:
  ```sh
  docker exec -ti kafka-kraft bash
  cd /opt/kafka/bin
  ./kafka-topics.sh --create --topic user_msgs --bootstrap-server localhost:9092
  ./kafka-topics.sh --create --topic word_count --bootstrap-server localhost:9092
  ```

  Another way:

  ```sh
  docker exec -ti kafka-kraft /opt/kafka/bin/kafka-topics.sh --create --topic user_msgs --bootstrap-server localhost:9092
  docker exec -ti kafka-kraft /opt/kafka/bin/kafka-topics.sh --create --topic word_count --bootstrap-server localhost:9092
  ```

* Start the SQL client inside the job manager
  ```sh
   docker exec -it jobmanager bash
   ./bin/slq-client.sh
  ```

* Create input table:
  ```sql
  CREATE TABLE `user_msgs` (
    -- The Kafka message value is the text we want to process
      message STRING,
      -- Add a processing time attribute for windowing (required for stream aggregation)
      proctime AS PROCTIME()
  ) WITH (
      'connector' = 'kafka',
      'topic' = 'user_msgs',
      'properties.bootstrap.servers' = 'kafka:9092', -- Adjust as needed
      'properties.group.id' = 'flink-word-count-group',
      'format' = 'json', -- We use JSON format for the key/value structure in Kafka
      'json.fail-on-missing-field' = 'false',
      'json.ignore-parse-errors' = 'true',
      -- Define the raw text message from the Kafka value (in this simplified setup)
      'value.format' = 'raw',
      'scan.startup.mode' = 'earliest-offset'
  );
  ```

* Create messages:
  ```sh
  docker exec -it kafka-kraft /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic user_msgs


  {"message": "Hello World"}
  {"message": "This is a test message"} 
  {"message": "world is great"}
  ```
* In the sql client verify messages are visible:
  ```sh
  select message from user_msgs;
  ```

* Implement the logic to count words in the messages, using the SPLIT function to get an array of strings and unnest to create as many rows as string in each array, then group by word. 
  ```sql
   select 
      word, 
      count(*) as word_count 
    from user_msgs 
    cross join  unnest (split(lower(message), ' ')) as T(word) 
    group by word;
  ```

  Because `group by` needs key, the kafka connector has to be upsert.

* Create sink table:
  ```sql
  CREATE TABLE `word_count` (
      word STRING PRIMARY KEY NOT ENFORCED,
      word_count DECIMAL
  ) WITH (
      'connector' = 'upsert-kafka',
      'topic' = 'word_count',
      'properties.bootstrap.servers' = 'kafka:9092',
      'key.format' = 'raw',
      'value.format' = 'json'
  );
  ```

* Add `insert into word_count` to the select developed above:
  ```sql
  insert into word_count
   select 
      word, 
      count(*) as word_count 
    from user_msgs 
    cross join  unnest (split(lower(message), ' ')) as T(word) 
    group by word;
  ```

* Verify messages in sink table
  ```sh
  docker exec -it  kafka-kraft  /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic word_count --from-beginning
  ```

Results looks like:
```
{"word":"hello","word_count":1}
{"word":"world","word_count":1}
{"word":"this","word_count":1}
{"word":"is","word_count":1}
{"word":"a","word_count":1}
{"word":"test","word_count":1}
{"word":"message","word_count":1}
{"word":"hello","word_count":2}
{"word":"world","word_count":2}
{"word":"this","word_count":2}
{"word":"is","word_count":2}
{"word":"a","word_count":2}
{"word":"test","word_count":2}
{"word":"message","word_count":2}
{"word":"world","word_count":3}
{"word":"is","word_count":3}
{"word":"great","word_count":1}
```

* Stop everything: `docker-compose down`


## Local Kafka and Flink binary execution 

12/5/2025, the Kafka connectors are not available for Flink 2.1.x. So this lab is done on version 1.20

* Start the Kafka server:
    ```sh
    KAFKA_HOME=/Users/jerome/Documents/Code/flink-studies/deployment/product-tar/kafka_2.13-4.1.1
    # from KAFKA_HOME
    $KAFKA_HOME/bin/kafka-server-start.sh config/server.properties
    ``` 

* Create the topics:
  ```sh
  $KAFKA_HOME/bin/kafka-topics.sh --create --topic user_msgs --bootstrap-server localhost:9092
  $KAFKA_HOME/bin/kafka-topics.sh --create --topic word_count --bootstrap-server localhost:9092
  ```

* Be sure to have the Kafka connector libraries for the matching Flink install:
  ```sh
  curl -L -O https://archive.apache.org/dist/flink/flink-1.20.0/flink-1.20.0-bin-scala_2.12.tgz

  tar -xzf flink-1.20.0-bin-scala_2.12.tgz
  # save the jar in the FLINK_HOME/lib folder
  ```

* Start Flink cluster after installing the kafka connector jar under $FLINK_HOME/lib (see [local installation](../../../deployment/product-tar/README.md)).  
  ```sh
  FLINK_HOME=/Users/jerome/Documents/Code/flink-studies/deployment/product-tar/flink-1.20.0
  $FLINK_HOME/bin/start-cluster.sh
  ```

* Start the SQL client inside the job manager
  ```sh
   $FLINK_HOME/bin/slq-client.sh
  ```

* For all table use the  `'properties.bootstrap.servers' = 'localhost:9092'` for the kafka access. As an example here is the creation of the input table:
  ```sql
  CREATE TABLE `user_msgs` (
    -- The Kafka message value is the text we want to process
      message STRING,
      -- Add a processing time attribute for windowing (required for stream aggregation)
      proctime AS PROCTIME()
  ) WITH (
      'connector' = 'kafka',
      'topic' = 'user_msgs',
      'properties.bootstrap.servers' = 'localhost:9092', -- Adjust as needed
      'properties.group.id' = 'flink-word-count-group',
      'format' = 'json', -- We use JSON format for the key/value structure in Kafka
      'json.fail-on-missing-field' = 'false',
      'json.ignore-parse-errors' = 'true',
      -- Define the raw text message from the Kafka value (in this simplified setup)
      'value.format' = 'raw',
      'scan.startup.mode' = 'earliest-offset'
  );
  ```

The rest is the same as in the docker compose section above.

* Stop flink cluster: 
  ```sh
  $FLINK_HOME/bin/stop-cluster.sh
  ```


## Using Confluent Platform on k8s

* Create topics via manifests
* Package sql or table api in a jar
* submit via application manifest


## Remote connection to Confluent Cloud Kafka Cluster

* Use confluent CLI  [See the Download page](https://docs.confluent.io/confluent-cli/current/install.html)

```sh
confluent login
confluent environment list
confluent environment use en-...
# if needed
confluent kafka cluster create my-cluster --cloud gcp --region us-central1 --type basic
confluent api-key create --resource <cluster-id> --description <cluster-name>-key -o json >  <cluster-name>-key.json
confluent kafka topic create user_msgs --cluster <cluster-id>
confluent kafka cluster describe <cluster-id>
```

* Use the same local docker compose with just task manager, job manager and SQL client containers, or use Flink OSS binary.
* Define the environment variables:
  ```sh
  export BOOTSTRAP_SERVER=pkc-n98pk.us-west-2.aws.confluent.cloud:9092
  export API_SECRET
  export API_KEY
  ```

* Create a table to connect to Kafka. Change the attributes with API_KEY, API_SECRETS and BOOTSTRAP_SERVER for the remote cluster

TO DO: makes this work

```sql
CREATE TABLE user_msgs (
  `message` STRING,
  `ts` TIMESTAMP(3)
) WITH (
  'connector' = 'kafka',
  'topic' = 'user_msgs',
  'properties.group.id' = 'demoGroup',
  'scan.startup.mode' = 'earliest-offset',
  'properties.bootstrap.servers' = '${env:BOOTSTRAP_SERVER}',
  'properties.security.protocol' = 'SASL_SSL',
  'properties.sasl.mechanism' = 'PLAIN',
  'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.plain.PlainLoginModule required username="${env:API_KEY}" password="${env:API_SECRET}";',
  'value.format' = 'json'
);
```

* Post message using curl: use as a bare toke: `echo $API_KEY:$API_SECRET | base64" 

```sh
curl --request POST  --url https://pkc-n98pk.us-west-2.aws.confluent.cloud/kafka/v3/clusters/lkc-3mnm0m/topics/user_msgs/records --header 'Authorization: Basic <token>' --data '{"partition_id":0,"value":{"type":"JSON", "data": {"message":"Bonjour world"}}}' --header 'content-type: application/json' 
```

### Problems

10/08/24  the module org.apache.kafka.common.security.plain.PlainLoginModule is missing in job and task managers. We  need to add libraries. Verify if these are the good paths in the dockerfile of sql-client. This is not aligned with https://github.com/confluentinc/learn-apache-flink-101-exercises/blob/master/sql-client/Dockerfile


CREATE TABLE user_msgs (
    `message` STRING,
    `ts` TIMESTAMP(3)
) WITH (
  'connector' = 'kafka',
  'topic' = 'user_msgs',
  'properties.group.id' = 'demoGroup',
  'scan.startup.mode' = 'earliest-offset',
  'properties.bootstrap.servers' = 'pkc-n98pk.us-west-2.aws.confluent.cloud:9092',
  'properties.security.protocol' = 'SASL_SSL',
  'properties.sasl.mechanism' = 'PLAIN',
  'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.plain.PlainLoginModule required username="..." password="c.."',
  'value.format' = 'json');


# to clean



## [optional] Use Kafka Connect Datagen connector

As an alternate we can use [Kafka Connector](https://github.com/confluentinc/kafka-connect-datagen) to generate random data using Faker.
Use the Docker image based on Kafka Connect with the [kafka-connect-datagen](https://hub.docker.com/r/cnfldemos/kafka-connect-datagen) plugin already installed.

* Use on Datagen Kafka connector configuration and post to the /connectors API:

```sh
curl -X POST -H "Content-Type: application/json" --data @datagen-config/shoe-products.json http://localhost:8083/connectors
```