# Moving from ELT/ETL to real time processing

This chapter tries to assess what needs to be considered when transforming logic and SQL scripts done for batch processing to real-time processing. There is no lift and shift it has to be refactoring as the SQL processing is different in most case where there is complexity and stateful operators like joins.

Most of the filtering and selection can be ported 1 to 1.

There is [a repository](https://jbcodeforce.github.io/shift_left_utils/) with tools using LLM to help on the shift-left migration.

## Time condiderations

## Joins considerations


The SQL, LEFT JOIN, joins records that match and don’t match on the condition specified. For non matching record the left columns are populated with NULL. SQL supports LEFT ANTI JOIN, but not Flink. So one solution in Flink AQL is to use a null filter on the left join condition:

```sql
from table_left
left join table_right
    on table_left.column_used_for_join = table_right.column_used_for_join
    where table_right.column_used_for_join is NULL;
```

