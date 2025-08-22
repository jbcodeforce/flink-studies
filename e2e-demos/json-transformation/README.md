# Simple Proof Of Concept for Confluent Platform Flink

This is a simple demo to use Confluent Platform with Flink to do a json mapping, a join and an aggregation.

The input is an industrial vehicle rental event. 

## Use Case

## CMF Setup

Be sure to have Confluent Platform deployed on kubernetes ([See this readme](../../deployment/k8s/cp-flink/README.md)) and use the makefile in deployment/k8s/cp-flink to start Colima, verify flink and Kafka. 

The cp-flink folder in this json-transformation project, includes a makefile to manage port-forwarding, create topics...

* Define raw-contract topic, json schema and schema entry
    ```sh
    make create_raw_contract_topic
    make create_raw_contract_cm
    make create_raw_contract_schema
    ```
* Validate we can see the catalog and table
    ```
    ```


### To do

* [x] create raw-contract topic
* [x] Create table raw-contract, with schema in registry
* [ ] Write producer of raw-contract

### Issues to fix

* [ ] Confluent Console connection error with port forwarding

## CCF Setup