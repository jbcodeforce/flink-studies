# Data Skew in Joins

Demonstrates how data skew arises in Flink SQL joins and how to mitigate it with the **salted-join** pattern.

See the [full explanation](https://jbcodeforce.github.io/flink-studies/concepts/#data-skew) in the Flink Studies documentation.

## Problem

When a join key is highly skewed (e.g., one `group_id` has millions of users while others have tens), all records with that key are routed to the same task manager subtask. This creates a hotspot: one subtask is overwhelmed while others are idle, causing high latency and potential back-pressure.

## Salted-Join Mitigation

The salted-join pattern distributes the skewed key across multiple subtasks by appending a **salt** integer (0 to N−1) to the join key. The right (reference) side is replicated N times — one copy per salt bucket. The left (probe) side assigns a random salt value per row, spreading the load.

```sql
-- Left side: assign a random salt
SELECT user_id, group_id, CAST(RAND() * 4 AS INT) AS salt
FROM users

-- Right side: replicate N=4 times using CROSS JOIN with a numbers table
SELECT g.group_id, g.group_name, n.salt
FROM groups g
CROSS JOIN (VALUES (0), (1), (2), (3)) AS n(salt)

-- Join on composite key (group_id, salt)
SELECT u.user_id, g.group_name
FROM salted_users u
JOIN salted_groups g
  ON  u.group_id = g.group_id
  AND u.salt     = g.salt
```

## Layout

```
cc-flink/    Confluent Cloud Flink SQL (insert data + join pipelines)
```

## Prerequisites

1. Confluent Cloud environment with a Flink compute pool
2. Deployment credentials in `../../../tools/`

## Run (Confluent Cloud)

```sh
cd cc-flink

make sync
make deploy-data      # seed users and groups
make deploy-pipeline  # run skewed join then salted join side-by-side

make undeploy
make drop-tables
```

## Files

| File | Purpose |
|------|---------|
| `insert_groups.sql` | Seed groups data — one large group to create skew |
| `insert_users.sql`  | Seed users data |
| `dml.joins_user_group.sql` | Baseline join showing hotspot behaviour |
| `dml.salted_joins.sql`     | Salted join that distributes the skewed key |
