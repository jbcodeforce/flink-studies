# Moving to a data product architecture

This chapter aims to present 
evaluate the considerations necessary for transforming logic and SQL scripts designed for batch processing into those suitable for real-time processing. 

## Context

The traditional architecture to organize data lakes is to use the 3 layers or medallion architecture as illustrated in the following figure:

![](./diagrams/medallion_arch.drawio.png)

The main motivations for the adoption of this architecture can be seen as:

* Get a huge amount of structured and unstructured data to cheaper storage provided by cloud object storage.
* Apply pipeline logic to do the data transformation between landing zones to business level aggregates
* Supposely easier to do data management and governance with data cataloging and distributed query tools
* Rather than structuring data around business domains or use cases, the Medallion Architecture categorises data purely based on its transformation stage.

### Challenges

* Not all data needs the 3 layers architecture and but a more service contract type of data usage. Data becoming a product like a microservice.
* There is a latecy issue to get the data, we talk about T + 1 to get fresh data. The + 1 can be one day or one hour, but it has latency that may not what business requirements need.
* Simple transformations need to be done with the ETL or ELT tool with the predefined staging. Not specific use-case driven implementation of the data retrieval and processing. 
* Data are **pulled** from their sources and between layers. It could be micro-batches, or long running batches. At the bronze layer, the data are duplicated, and there is minimum of quality control done.
* In the silver layer the filtering and transformations are also generic with no specific business context.
* The gold layer includes all data of all use cases. This is where most of the work is done for data preparation and develop higher quality level. This is the layer with a lot of demands from end-user and continuous update and new aggregation developments. 
* This is the final consumer of the data lake gold layer that are pulling the data with specific Service Level Objectives. 
* Data created at the gold level, most likely needs to be reingected to the operational databases to be visible to operation applications. This introduces the concept of reverse ETL. 
* Each layer may have dfferent actors responsible to process the data: data platform engineer, analytic engineers and data modelers, and at the application level, the application developers.
* Storing multiple copies of data across layers inflates cloud storage expenses. Data become quickly stale and unreliable.
* Constant movement of data through layers results in unnecessary processing and query inefficiencies.
* The operational estate is also continuously growing, with mobile applications, serverless functions, cloud native apps, etc...

### Moving to Kafka and real time processing

Changing the technologies but using the medallion architecture does not solve the problem and is not a data centric product architecture. The following diagram illustrates the same layers, done with Flink processing and Kafka topic for persistence.

![](./diagrams/hl-rt-integration.drawio.png)

Using topics as storage of data records and Flink for transsforming, filtering and enriching to the silver layer, also using kafka topics is the same ETL approach with different technologies. 

A more detailed view, using Kafka Connectors will look like in the diagram below, where the three layers are using the Kimdall practices of source processing, intermediates and sinks.

![](./diagrams/generic_src_to_sink_flow.drawio.png)

## A data product approach

Data product is designed with a domain-driven model combined with analytical and operational use cases. The methodology to define data product may be compared to the microservice adoption, and even the event-driven microservice. The core paradigm shift is to move to a push mechanism where data applications push business context data with a use case centric serving capability. Aggregation processing is considered as a service pushing data product to other consumers. The aggregate models make specific queries on other data products and serve the results with SLOs.

The design starts by the user input, which are part of a business domain and business context. The data may be represented as DDD aggregate with a semantic model. [Entities and Value objects](https://jbcodeforce.github.io/eda-studies/methodology/ddd/#entities-and-value-objects) are represented to assess the need to reuse other data product and potentially assess the need for anti corruption layer. 

In data products, DDD bounded context, translates to defining clear boundaries for the data products, ensuring each product serves a specific business domain. A `customer data product` and a `product inventory data product` would be distinct bounded contexts, each with its own data model and terminology

Data pushed to higher consumer are part of the semantic model, and event-driven design. Analytics Engineers and Data Modellers building aggregate Data Products know exactly what to collect and what quality measures to serve. The aggregation may use lean-pull mechanism, focusing on their use case needs only. The data is becoming a product as closed to the operational source, so shifting the processing to the left of the architecture. This Shift-Left approach where quality controls, validation, and governance mechanisms are embedded as early in the data lineage map as possible. The consumption patterns are designed as part of the data product, and may include APIs, events, real-time streams or even scheduled batch.

Moving from technical data delivery to product thinking requires changes in how organizations approach data management. New requirements are added to the context of the source semantic model.

## Motivations for moving to data stream processing

The Data integration adoption is evolving with new needs to act on real-time data and reduce batch processing cost and complexity. The following table illustrates the pros and cons of data integration practices for two axes: time to insights and data integity

| Time to insights | | Data integrity | 
| --- | --- | --- |
| | **Low**  | **High**       |
| **High** | **Lakehouse or ELT:** + Self-service. - Runaway cost, - No knowledge of data lost, - complext data governance, - data silos. | **Data Stream Platform:** + RT decision making, + Operation and analytics on same platform. + Single source of truth, + Reduced TCO, + Governance | 
| **Low** | **Hand coding:** + customized solution specific to needs. - Slow, - difficult to scale, - opaque, - challenging governance. | **ETL:** + Rigorous, + data model design, + governed, + reliable. - Slow, - Point to point, - Difficult to scale. | 

### Assessment questions

Try to get an understanding of the data integration requirements by looking at:

* Current data systems and data producers to a messaging system like Kafka
* Development time to develop new streaming logic or ETL job
* What are the different data landing zones and for what purpose. Review zone ownership.
* Level of Lakehouse adoption and governance, which technology used (Iceberg?)
* Is there a data loop back from the data lake to the OLTP?
* Where data cleaning is done?
* Is there any micro-batching jobs currently done, at which frequency, for which consuners?
* What data governance used?
* How data quality control is done?

## Migration Context

A direct "lift and shift" approach—where SQL scripts are converted to Flink statements on a one-to-one basis—is not feasible. Refactoring is essential, as SQL processing often differs significantly in cases involving complexity and stateful operators, such as joins.

Most of the filtering and selection scripts can be ported 1 to 1. While most stateful processing needs to be refactorized and deeply adapted to better manage states and complexity.

There is [a repository](https://jbcodeforce.github.io/shift_left_utils/) with tools to process existing dbt project to find dependencies between tables, use local LLM to do some transformations, and create target pipelines per sink table.

## Time condiderations

## Some implementation challenges

### Joins considerations


The SQL, LEFT JOIN, joins records that match and don’t match on the condition specified. For non matching record the left columns are populated with NULL. SQL supports LEFT ANTI JOIN, but not Flink. So one solution in Flink AQL is to use a null filter on the left join condition:

```sql
from table_left
left join table_right
    on table_left.column_used_for_join = table_right.column_used_for_join
    where table_right.column_used_for_join is NULL;
```

