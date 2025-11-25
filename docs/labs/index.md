# Local labs / demos and other public demonstrations

This section lists the current demonstrations and labs in this git repository or the interesting public repositories about Flink

## Local demonstrations and end to end studies

All the local demonstrations run on local Kubernetes, some on Confluent Cloud. Most of them are still work in progress.

See the [e2e-demos](https://github.com/jbcodeforce/flink-studies/tree/master/e2e-demos) folder for a set of available demos based on the Flink local deployment or using Confluent Cloud for Flink.

Those demos are not finalized:

* [ ] [Record deduplication](https://github.com/jbcodeforce/flink-studies/tree/master/e2e-demos/dedup-demo) using Flink SQL or Table API deployed on Confluent Platform for Flink
* [ ] [Change Data Capture with Postgresql](https://github.com/jbcodeforce/flink-studies/tree/master/e2e-demos/cdc-demo), CDC Debezium, Confluent Platformm v8.0+, Cloud Native for Postgresql Kuberneted Operator
* [ ] [e-commerce sale](https://github.com/jbcodeforce/flink-studies/tree/master/e2e-demos/e-com-sale)
* [ ] [Transform json records](https://github.com/jbcodeforce/flink-studies/tree/master/e2e-demos/json-transformation)
* [ ] [Qlik CDC emulated to Flink dedup, filtering, transform logic](https://github.com/jbcodeforce/flink-studies/tree/master/e2e-demos/cdc-dedup-transform)
* [ ] [External lookup](https://github.com/jbcodeforce/flink-studies/tree/master/e2e-demos/external-lookup)
* [ ] Flink to JDBC Sink connector
* [ ] Savepoint demonstration
* [ ] SQL Gateway demonstration
* [ ] Terraform deployment
* [ ] GitOps with Openshift, ArgoCD and Tekton


## Public repositories with valuable demonstrations


* [Managing your Confluent Cloud Flink project at scale with a CLI](https://github.com/jbcodeforce/shift_left_utils)
* [Confluent Flink how to](https://docs.confluent.io/cloud/current/flink/reference/sql-examples.html#)
* [Confluent demonstration scene](https://github.com/confluentinc/demo-scene): a lot of Kafka, Connect, and ksqlDB demos
* [Confluent developer SQL training](https://developer.confluent.io/courses/flink-sql/overview/)
* [Confluent Quick start with streaming Agents](https://github.com/confluentinc/quickstart-streaming-agents)
* [lab 3- Agentic Fleet Management Using Confluent Intelligence](https://github.com/confluentinc/quickstart-streaming-agents/blob/master/LAB3-Walkthrough.md)

* [Demonstrate Flink SQL test harness tool for Confluent Cloud Flink](https://jbcodeforce.github.io/shift_left_utils/coding/test_harness/#usage-and-recipe).
* [Demonstrations for data as a product methodolgy, moving from Spark batch processing to Flink using shift_left utils.](https://github.com/jbcodeforce/flink_project_demos)
* [Shoes Store Labs](https://github.com/jbcodeforce/shoe-store)  to run demonstrations on Confluent Cloud. 

## Interesting Blogs

* [Building Streaming Data Pipelines, Part 1: Data Exploration With Tableflow](https://www.confluent.io/blog/building-streaming-data-pipelines-part-1/)
* [Building Streaming Data Pipelines, Part 2: Data Processing and Enrichment With SQL](https://www.confluent.io/blog/streaming-etl-flink-tableflow/)

## Quick personal demo for Confluent Cloud for Flink

Using the data generator and the `confluent flink shell`

* Login to Confluent using cli
* Be sure to use the environment with the compute pool: 

```sh
confluent environment list
confluent environment use <env_id>
confluent flink compute-pool list
# get the region and cloud and the current max CFU
confluent flink compute-pool use <pool_id>
```

* Start one of the Datagen in the Confluent Console. 

TBC