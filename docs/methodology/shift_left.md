# Moving to a data as a product architecture

This chapter aims to summarize the current challenges of big data / data lake or lakehouse practices and architecture, and how to adopt a data as a product architecture in the context of understanding how  real-time streaming capability fits into this paradigm shift of designing solutions.

## Context

### Operational Data and Analytical data

The data landscape is split between operational data, which powers real-time applications, and analytical data, which provides historical insights for decision-making and machine learning. This separation has created complex and fragile data architectures, marked by problematic ETL processes and intricate data pipelines. The challenge lies in effectively bridging these two distinct data planes to ensure seamless data flow and integration.

![](./diagrams/data_op_data_planes.drawio.png)

The first implementation generation of those two planes where based on database on the left side, data warehouse on the right, and ETL jobs for pipelines. Because of scaling needs and the need to support unstructurured data, the 2nd generation, starting mid 2000s adopts distributed object storage, forming the Data Lake.   

TBC 

The traditional architecture to organize data lakes is to use the 3 layers or medallion architecture as illustrated in the following figure:

![](./diagrams/medallion_arch.drawio.png)

The main motivations for the adoption of this architecture can be seen as:

* Get a huge amount of structured and unstructured data to cheaper storage provided by cloud object storage.
* Apply pipeline logic to do the data transformation between landing zones to business level aggregates
* Supposely easier to do data management and governance with data cataloging and distributed query tools
* Rather than structuring data around business domains or use cases, the Medallion Architecture categorises data purely based on its transformation stage.

### Challenges

* We observe complex ETL jobs landscape, with high failure rate
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

### Data products

Data products serve analytical data, they are self-contained, deployable, valuable and exhibit eight characteristics:

* **Discoverable**: data consumers can easily find the data product for their use case
* **Addressable**: with a unique address accessible programmatically
* **Self describable**: Clear description of the purpose and usage patterns 
* **Trustworthy**: clear Service Level Objectives and Service Level Indicators conformance
* **Native access**: adapt the access interface to the consumer: APIs, events, SQL views, reports, widgets
* **Composable**: integrate with other data products, for joining, filtering and aggregation
* **Valuable**: represent a cohesive concept within its domain. Sourced from unstructured, semi-structured and structured data. To maximize value within a data mesh, data products should have narrow, specific definitions, enabling reusable blueprints and efficient management.
* **Secure**: with access control rules and enforcement

They are not data applications, data warehouses, PDF reports, dashboards, tables (without proper metadata), or kafka topics.

### Methodology

Defining, designing and implementing data products follow the same principles as other software development and should start by the end goal and use case. This should solidify clear product objectives. Do not start from data sources. Some example of use cases:

<style>
table th:first-of-type {
    width: 60%;
}
table th:nth-of-type(2) {
    width: 40%;
}
</style>
| User Story| Data Products |
| --- | --- |
| As a **marketing strategist**, I need to provide predictive churn scores and customer segmentation based on behavior and demographics. This will allow me to proactively target at-risk customers with personalized retention campaigns and optimize marketing spend. | <ul><li>Churn probability scores for each customer.</li><li>Customer segments based on churn risk and value.</li> <li>Key factors influencing churn.</li></ul> |
| As a **product manager**, I need to visualize key product usage metrics and performance indicators. This will enable me to monitor product adoption, identify usage patterns, and make data-driven decisions for product improvements. |  <ul><li>Active users, feature usage, and conversion rates.</li><li>Historical trends and comparisons of product performance.</li><li>Breakdowns of product usage by customer segment</li><li>Alerts for anomalies or significant changes in product usage</li></ul>
| As a **supply chain manager**, I need to get real-time visibility into inventory levels, supplier performance, and delivery timelines. This will help me proactively identify potential disruptions, optimize inventory management, and ensure timely product delivery. | <ul><li>Real-time inventory levels across all warehouses.</li><li>Supplier performance metrics, such as on-time delivery rates and quality scores.</li><li>Predictive alerts for potential stockouts or delivery delays.</li><li>Visualizations of delivery routes and timelines.</li><li>Historical data that can be used to perform trend analysis, and find bottlenecks.</li></ul>| 

Using classical system context diagram we can define an high level view of a data product as:

![](./diagrams/dp_sys_ctx.drawio.png)


Data as a product is designed with a domain-driven model combined with analytical and operational use cases. 

The methodology to define data product may be compared to the microservice adoption, and even the event-driven microservice. The core paradigm shift is to move to a push mechanism where data applications push business context data with a use case centric serving capability. Aggregation processing is considered as a service pushing data product to other consumers. The aggregate models make specific queries on other data products and serve the results with SLOs.

The design starts by the user input, which are part of a business domain and business context. The data may be represented as DDD aggregate with a semantic model. [Entities and Value objects](https://jbcodeforce.github.io/eda-studies/methodology/ddd/#entities-and-value-objects) are represented to assess the need to reuse other data product and potentially assess the need for anti corruption layer. 

In data products, DDD bounded context, translates to defining clear boundaries for the data products, ensuring each product serves a specific business domain. A `customer data product` and a `product inventory data product` would be distinct bounded contexts, each with its own data model and terminology

Data pushed to higher consumer are part of the semantic model, and event-driven design. Analytics Engineers and Data Modellers building aggregate Data Products know exactly what to collect and what quality measures to serve. The aggregation may use lean-pull mechanism, focusing on their use case needs only. The data is becoming a product as closed to the operational source, so shifting the processing to the left of the architecture. This Shift-Left approach where quality controls, validation, and governance mechanisms are embedded as early in the data lineage map as possible. The consumption patterns are designed as part of the data product, and may include APIs, events, real-time streams or even scheduled batch.

Moving from technical data delivery to product thinking requires changes in how organizations approach data management. New requirements are added to the context of the source semantic model.

### 
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

