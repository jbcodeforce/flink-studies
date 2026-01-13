# A set of end-to-end demonstrations

For each demonstrations it should be easy to deploy, have a readme to explain the goals, what will be learn, how to setup and how to validate the demonstration.

## CP-Flink Demonstrations

### Tracking
| Name | Readme | Make | Demo Script | Status |
|------|--------|------|--------|--------|
| json-transform | Yes | | | 

### Proof of concept for QLik CDC processing with Confluent Cloud Flink

[Detailed Readme](./cdc-dedup-transform/)

### Json Transformation

* [Readme](./json-transformation/README.md)
* [To Do](./json-transformation/checklist.md)

## CC-flink Demonstrations

* [cc-cdc-tx-demo](./cc-cdc-tx-demo/README.md) CDC from Postgresql tables, Debezium envelop processing, deduplication, delete operation propagation, statefule windowing processing. Finance Domain: customer, transaction. Terraform deployment: RDS, kafka cluster, connectors, compute pool, S3, Redshift.