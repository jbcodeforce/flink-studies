# Streamhouse

Streamhouse is Confluent’s vision for a real-time operating layer for business data. The Streamhouse is positioned as a central hub for data to flow from operational data sources to the lakehouse, other operational applications, and agents. 

**"software is moving from analysing the business to running it"**

It continuously captures changes, processes and governs them, maintains an always-current view of the business, and serves that data to applications, analytics, and AI agents. Streamhouse is not just for the analytical estate alone. Its true strength lies in its integration with the operational estate. Reverse ETL, decoupling processing bottlenecks, operationalizing analytical aggregations, anomaly detection, fraud risk scoring.

Most important metrics: time to query from data creation at cost.

In simple terms:

* Warehouse: tells you what happened.
* Lakehouse: helps you model and analyze what happened.
* Streamhouse: helps you know what is true now and act on it immediately.  

It is not intended to replace a warehouse or lakehouse; it works alongside them as a real-time layer.  

Confluent’s Streamhouse is built around five capabilities:

* Connect data sources
* Stream data
* Process data with Flink
* Govern data
* Query and serve current data through capabilities such as Lightning Tables, Snapshot Queries, Real-Time Context Engine, and Tableflow 

## Some streaming capabilities

* Analytical use cases prioritize highly consistent exactly-once guarantees and can tolerate processing latency spikes due to job maintenance
* Operational estate prioritizes highly available pipelines with minimal end-to-end processing latency.

For low latency, the simplest way to support it, is to use at-least-once guarantees since operational use-cases typically have idempotent downstream consumers. For lakehouse integration, this one is forced to deduplicate. Reducing the exactly-once transaction commitment interval to 10s or 5s would help less latency-sensitive operational cases that benefit from exactly-once too.

Unlike reporting analytics dashboards, operational use-cases need to adhere to strict SLAs like any other micro-service.