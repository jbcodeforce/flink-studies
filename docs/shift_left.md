# Moving from ELT/ETL to real time processing

This chapter aims to evaluate the considerations necessary for transforming logic and SQL scripts designed for batch processing into those suitable for real-time processing. A direct "lift and shift" approach—where SQL scripts are converted to Flink statements on a one-to-one basis—is not feasible. Refactoring is essential, as SQL processing often differs significantly in cases involving complexity and stateful operators, such as joins.

Most of the filtering and selection scripts can be ported 1 to 1. While most stateful processing needs to be refactorized and deeply adapted to better manage states and complexity.

There is [a repository](https://jbcodeforce.github.io/shift_left_utils/) with tools to process existing dbt project to find dependencies between table, use local LLM to do some transformations, and create target pipelines per sink table.

## Motivation for moving to data stream processing

The Data integration adoption is evolving with new need to act on real-time data and reduce batch processing cost and complexity. The following table illustrates the pros and cons of data integration practices for two axes: time to insights and data integity

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

