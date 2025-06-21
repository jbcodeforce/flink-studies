# Confluent Tableflow

[Product blog](https://www.confluent.io/blog/introducing-tableflow/)

## Goals

Allow to represent a Kafka topic as a table in [Apache Iceberg](https://iceberg.apache.org/) or Delta Lake format. It becomes the mediation layer between operational data and analytical data zone. It is using Schema registry to get the schema definition of the table.  It addresses a unified storage view on top of object storage.

Kafka topic is the source of truth of the data. Tableflow supports the open table format: a table and catalog for analytics. It is part of the [data as a product](../methodology/data_as_a_product.md) architecture.

For Data engineers in data lakehouse environment, kafka topic is seen as table.
### Value Propositions

* It is a Cloud service, per region.
* The data from the topic is moved to object storage in **parquet format** with **Iceberg metadata**. 
* Need to bring your own object storage (s3 bucket)
* Work with private network, using gateway private endpoints to S3. No traffic over public internet.
* Data refreshness is down to 15mn, default 6 hours. For higher need, it can read from broker directly, at the minute level.
* Start from the earliest offset.
* Can compact multiple small files in bigger file.
* It keeps track of committed osffset in iceberg.
* Write data as encrypted at source level.
* Charge for sink connector and egress is waived, pricing is based on per topic/hour and GB processed.

### Current limitations

* Consume only from append log topic, and non compacted topic.
* DLQ not supported yet
* Not changing the log type once enabled.
* No support BYOK clusters
* Could 

## Architecture

* Kafka cluster on Confluent Cloud
* Tableflow capability
* S3 access policy and service role

## Persisted Data in S3

* Keep metadata of records in original topic like topic name, timestamp and offset

