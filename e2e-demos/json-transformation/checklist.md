# Implementation checklist

This checklist outlines the implementation items to complete the demonstration.

## Core Features

* [ ] Readme to present problem, implementation approach and deployment
* [ ] Readme - Demonstration script
* [ ] Master makefile to build, deploy and status on all components
* [x] Makefile to build and deploy Demo App 
* [x] Makefile to build and deploy Table API Flink app
* [x] SQL transformation for `raw_jobs` to `job detail`. It is part of the dml.orderdetails.sql processing.
* [x] xform `raw-orders` to order details
* [x] join job and orders to order details
* [x] Add creation of the target output topic, schema and ConfigMap for`OrderDetails`
* [ ] Add analytics aggregates in SQL to another topic


