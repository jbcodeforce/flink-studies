"""Convert Flink INSERT INTO DML statements to dbt streaming_table models."""

from flink_dbt_migrate.migrate import migrate_dml_to_dbt

__all__ = ["migrate_dml_to_dbt"]
