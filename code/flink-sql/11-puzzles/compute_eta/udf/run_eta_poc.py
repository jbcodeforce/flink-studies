"""
Run compute_eta pipeline end-to-end: register estimate_delivery UDTF, then execute
DDL and DML from the parent compute_eta directory. Run with CWD = compute_eta so
paths data/shipment_events.json and data/shipment_history resolve.
"""
import os
import re
import sys

# So "from estimate_delivery import estimate_delivery" finds the UDF when run from compute_eta
UDF_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, UDF_DIR)

COMPUTE_ETA_DIR = os.path.dirname(UDF_DIR)

from pyflink.table import EnvironmentSettings, TableEnvironment


def parse_sql_file(path: str) -> list[str]:
    """Split SQL file on semicolon, strip comments and blank statements."""
    with open(path, "r") as f:
        content = f.read()
    # Remove line comments
    content = re.sub(r"--[^\n]*", "\n", content)
    statements = []
    for stmt in content.split(";"):
        stmt = stmt.strip()
        if stmt:
            statements.append(stmt + ";")
    return statements


def main():
    os.chdir(COMPUTE_ETA_DIR)

    t_env = TableEnvironment.create(EnvironmentSettings.in_batch_mode())
    t_env.get_config().set("parallelism.default", "1")

    from estimate_delivery import estimate_delivery

    t_env.create_temporary_system_function("estimate_delivery", estimate_delivery)

    ddl_shipments = os.path.join(COMPUTE_ETA_DIR, "ddl.shipments_table.sql")
    ddl_history = os.path.join(COMPUTE_ETA_DIR, "ddl.shipment_history.sql")
    dml_history = os.path.join(COMPUTE_ETA_DIR, "dml.shipment_history.sql")
    dml_eta = os.path.join(COMPUTE_ETA_DIR, "dml.compute_eta.sql")

    for path in (ddl_shipments, ddl_history):
        for stmt in parse_sql_file(path):
            t_env.execute_sql(stmt)

    for stmt in parse_sql_file(dml_history):
        t_env.execute_sql(stmt).wait()

    for stmt in parse_sql_file(dml_eta):
        t_env.execute_sql(stmt).print()


if __name__ == "__main__":
    main()
    sys.exit(0)
