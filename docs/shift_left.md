# Moving from ELT/ETL to real time processing

This chapter tries to assess what needs to be considered when transforming logic and SQL scripts done for batch processing to real-time processing. There is no lift and shift it has to be refactoring as the SQL processing is different in most case where there is complexity and stateful operators like joins.

Most of the filtering and selection can be ported 1 to 1.

## Time condiderations

## Joins considerations


In SQL LEFT JOIN joins records that match and don’t match on the condition specified. For non matching record the left columns are populated with NULL. SQL supports Left anti join, but not Flink, but can be done using a null filter on the left join condition:

```
```