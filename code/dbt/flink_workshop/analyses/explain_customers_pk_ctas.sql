-- Lab 1.2 — physical plan for CTAS (run manually in Flink SQL workspace with EXPLAIN prefix).
-- Not deployed by dbt run; use: EXPLAIN <paste compiled CTAS or run this file in the UI>.
--
-- CREATE TABLE `customers_pk` (
--   PRIMARY KEY(`account_number`) NOT ENFORCED,
--   WATERMARK FOR `created_at` AS `created_at` - INTERVAL '5' SECONDS
-- )
--   WITH ('changelog.mode' = 'upsert')
-- AS SELECT * FROM `customers_faker`;

select * from {{ ref('customers_faker') }}
