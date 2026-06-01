"""
Deploy or undeploy Flink SQL statements on Confluent Cloud via confluent-sql (REST API).

Reusable from demo folders: point at a SQL directory and a deploy manifest (JSON).
"""

from __future__ import annotations

import json
import os
import sys
import time
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import confluent_sql
from confluent_sql.exceptions import OperationalError, StatementNotFoundError
from dotenv import load_dotenv

DEFAULT_MANIFEST = "deploy_manifest.json"
DEFAULT_USER_AGENT = "flink-studies-sql-tools/0.1"
POLL_INTERVAL_SEC = float(os.environ.get("FLINK_POLL_INTERVAL", "5"))
STATEMENT_TIMEOUT_SEC = int(os.environ.get("FLINK_STATEMENT_TIMEOUT", "600"))

StatementRef = tuple[str, str]


@dataclass(frozen=True)
class DeployManifest:
    user_agent: str
    groups: dict[str, list[StatementRef]]
    deploy_all: list[str]
    undeploy_all: list[str]
    drop_tables: list[str]
    drop_statement_prefix: str | None = None

    def statements_for(self, group: str) -> list[StatementRef]:
        if group == "all":
            out: list[StatementRef] = []
            for g in self.deploy_all:
                out.extend(self.groups.get(g, []))
            return out
        if group not in self.groups:
            raise KeyError(f"Unknown group {group!r}; available: {sorted(self.groups)}")
        return list(self.groups[group])

    def undeploy_order(self, group: str) -> list[StatementRef]:
        return list(reversed(self.statements_for(group)))

    def statements_for_full_undeploy(self) -> list[StatementRef]:
        """Statement delete order: stop streaming DML before one-shot inserts."""
        groups = self.undeploy_all or [
            g for g in self.groups if g != "ddl"
        ]
        ordered: list[StatementRef] = []
        for group in reversed(groups):
            ordered.extend(reversed(self.groups.get(group, [])))
        return ordered

    def drop_statement_name(self, table: str) -> str:
        prefix = self.drop_statement_prefix or "drop"
        safe_table = table.replace(".", "-")
        return f"{prefix}-{safe_table}"


def load_dotenv_file() -> None:
    env_file = os.environ.get("CONFLUENT_ENV_FILE") or str(Path.home() / ".confluent" / ".env")
    load_dotenv(env_file)


def get_config() -> dict[str, str]:
    api_key = os.environ.get("FLINK_API_KEY") or os.environ.get("CONFLUENT_CLOUD_API_KEY")
    api_secret = os.environ.get("FLINK_API_SECRET") or os.environ.get("CONFLUENT_CLOUD_API_SECRET")
    org_id = os.environ.get("ORGANIZATION_ID") or os.environ.get("ORG_ID")
    env_id = (
        os.environ.get("ENVIRONMENT_ID")
        or os.environ.get("ENV_ID")
    )
    pool_id = (
        os.environ.get("FLINK_COMPUTE_POOL_ID")
        or os.environ.get("CPOOLID")
    )
    database = (
        os.environ.get("FLINK_DATABASE_NAME")
    )
    cloud = os.environ.get("CLOUD_PROVIDER") or "aws"
    region = os.environ.get("CLOUD_REGION") or "us-west-2"
    endpoint = os.environ.get("FLINK_BASE_URL") or os.environ.get("FLINK_REST_ENDPOINT")

    missing = []
    if not api_key or not api_secret:
        missing.append("FLINK_API_KEY and FLINK_API_SECRET (or CONFLUENT_CLOUD_API_KEY/SECRET)")
    if not org_id:
        missing.append("ORGANIZATION_ID")
    if not env_id:
        missing.append("ENVIRONMENT_ID or ENV_ID")
    if not pool_id:
        missing.append("FLINK_COMPUTE_POOL_ID")
    if not database:
        missing.append("FLINK_DATABASE_NAME")

    if missing:
        print("Missing required environment variables:", ", ".join(missing), file=sys.stderr)
        sys.exit(1)

    cfg: dict[str, str] = {
        "FLINK_API_KEY": api_key,
        "FLINK_API_SECRET": api_secret,
        "ORGANIZATION_ID": org_id,
        "ENVIRONMENT_ID": env_id,
        "FLINK_COMPUTE_POOL_ID": pool_id,
        "FLINK_DATABASE_NAME": database,
        "CLOUD_PROVIDER": cloud,
        "CLOUD_REGION": region,
    }
    if endpoint:
        cfg["ENDPOINT"] = endpoint.rstrip("/")
    return cfg


def load_manifest(manifest_path: Path) -> DeployManifest:
    data: dict[str, Any] = json.loads(manifest_path.read_text())

    groups: dict[str, list[StatementRef]] = {}
    for group_name, entries in data.get("groups", {}).items():
        groups[group_name] = [(e["name"], e["file"]) for e in entries]

    deploy_all = data.get("deploy_all")
    if not deploy_all:
        deploy_all = list(groups.keys())

    undeploy_all = data.get("undeploy_all")
    drop_tables = data.get("drop_tables", [])
    if isinstance(drop_tables, list) and drop_tables and isinstance(drop_tables[0], dict):
        drop_tables = [entry["table"] for entry in drop_tables]

    drop_prefix = data.get("drop_statement_prefix")
    if not drop_prefix and groups.get("ddl"):
        first_name = groups["ddl"][0][0]
        if "-ddl-" in first_name:
            drop_prefix = first_name.split("-ddl-")[0]

    return DeployManifest(
        user_agent=data.get("user_agent", DEFAULT_USER_AGENT),
        groups=groups,
        deploy_all=deploy_all,
        undeploy_all=undeploy_all or [],
        drop_tables=drop_tables,
        drop_statement_prefix=drop_prefix,
    )


def read_sql(sql_dir: Path, rel: str) -> str:
    path = sql_dir / rel
    if not path.exists():
        raise FileNotFoundError(f"SQL file not found: {path}")
    return path.read_text().strip()


def classify_sql(sql: str) -> str:
    s = sql.strip().lower()
    while s.startswith("--"):
        nl = s.find("\n")
        if nl == -1:
            return "snapshot_ddl"
        s = s[nl + 1 :].lstrip()

    if s.startswith("insert into"):
        if " select " in s:
            return "streaming_dml"
        return "batch_dml"
    if s.startswith("create table ") and " as select " in s:
        return "streaming_dml"
    elif s.startswith("create table ") or s.startswith("drop table "):
        return "snapshot_ddl"
    return "snapshot_dml"


def statement_properties(config: dict[str, str]) -> dict[str, str]:
    return {}
    # return {
    #     "sql.current-catalog": config["ENVIRONMENT_ID"],
    #     "sql.current-database": config["FLINK_DATABASE_NAME"],
    # }


@contextmanager
def flink_connection(config: dict[str, str], *, user_agent: str = DEFAULT_USER_AGENT):
    connect_kwargs: dict = {
        "flink_api_key": config["FLINK_API_KEY"],
        "flink_api_secret": config["FLINK_API_SECRET"],
        "environment_id": config["ENVIRONMENT_ID"],
        "compute_pool_id": config["FLINK_COMPUTE_POOL_ID"],
        "organization_id": config["ORGANIZATION_ID"],
        "database": config["FLINK_DATABASE_NAME"],
        "http_user_agent": user_agent,
    }
    if config.get("FLINK_REST_ENDPOINT"):
        connect_kwargs["endpoint"] = config["FLINK_REST_ENDPOINT"]
    else:
        connect_kwargs["cloud_provider"] = config["CLOUD_PROVIDER"]
        connect_kwargs["cloud_region"] = config["CLOUD_REGION"]

    conn = confluent_sql.connect(**connect_kwargs)
    try:
        yield conn
    finally:
        conn.close()


def wait_for_phases(
    conn,
    statement_name: str,
    accepted: set[str],
    *,
    timeout: int = STATEMENT_TIMEOUT_SEC,
) -> None:
    deadline = time.monotonic() + timeout
    poll = POLL_INTERVAL_SEC

    while time.monotonic() < deadline:
        stmt = conn.get_statement(statement_name)
        phase = stmt.phase.name
        if phase in accepted:
            print(f"  {statement_name}: {phase}")
            return
        if phase in ("FAILED", "FAILING"):
            detail = ""
            if isinstance(stmt.status, dict):
                detail = stmt.status.get("detail", "")
            raise RuntimeError(f"Statement {statement_name} {phase}: {detail}")
        time.sleep(poll)

    raise TimeoutError(
        f"Statement {statement_name} did not reach {sorted(accepted)} within {timeout}s"
    )


def submit_statement(conn, config: dict[str, str], name: str, sql: str) -> None:
    props = statement_properties(config)
    kind = classify_sql(sql)
    pool = config["FLINK_COMPUTE_POOL_ID"]

    if kind == "snapshot_ddl":
        conn.execute_snapshot_ddl(
            sql,
            statement_name=name,
            properties=props,
            compute_pool_id=pool,
            timeout=STATEMENT_TIMEOUT_SEC,
        )
        #wait_for_phases(conn, name, {"RUNNING", "COMPLETED"})
        return

    if kind in ("streaming_dml", "batch_dml"):
        with conn.closing_streaming_cursor() as cur:
            cur.execute(
                sql,
                statement_name=name,
                properties=props,
                compute_pool_id=pool,
                timeout=STATEMENT_TIMEOUT_SEC,
            )
        accepted = {"RUNNING", "COMPLETED"} if kind == "streaming_dml" else {"RUNNING", "COMPLETED"}
        #wait_for_phases(conn, name, accepted)
        return

    raise ValueError(f"Unsupported SQL classification for {name}: {kind}")


def run_create(conn, config: dict[str, str], name: str, sql_content: str) -> None:
    print(f"Creating statement: {name}")
    try:
        submit_statement(conn, config, name, sql_content)
    except OperationalError as exc:
        if exc.http_status_code != 409:
            detail = str(exc)
            if exc.http_status_code is not None:
                detail = f"{detail} (HTTP {exc.http_status_code})"
            raise RuntimeError(f"Failed to create {name}: {detail}") from exc
        print(f"  {name}: already exists (409), deleting and retrying")
        run_delete(conn, name, quiet=True)
        submit_statement(conn, config, name, sql_content)


def run_delete(conn, name: str, *, quiet: bool = False) -> None:
    if not quiet:
        print(f"Deleting statement: {name}")
    try:
        conn.delete_statement(name)
    except StatementNotFoundError:
        if not quiet:
            print(f"  {name}: not found")
        return

    deadline = time.monotonic() + STATEMENT_TIMEOUT_SEC
    poll = POLL_INTERVAL_SEC
    while time.monotonic() < deadline:
        try:
            conn.get_statement(name)
        except StatementNotFoundError:
            if not quiet:
                print(f"  {name}: deleted")
            return
        time.sleep(poll)

    raise TimeoutError(f"Statement {name} still present after delete")


def deploy_statements(
    statements: list[StatementRef],
    *,
    sql_dir: Path,
    config: dict[str, str],
    user_agent: str,
) -> None:
    with flink_connection(config, user_agent=user_agent) as conn:
        for name, rel in statements:
            run_create(conn, config, name, read_sql(sql_dir, rel))


def undeploy_statements(
    statements: list[StatementRef],
    *,
    config: dict[str, str],
    user_agent: str,
) -> None:
    with flink_connection(config, user_agent=user_agent) as conn:
        for name, _ in statements:
            run_delete(conn, name)


def run_drop_table(
    conn,
    config: dict[str, str],
    table: str,
    statement_name: str,
) -> None:
    sql = f"DROP TABLE IF EXISTS {table}"
    print(f"Dropping table: {table} (statement: {statement_name})")
    try:
        submit_statement(conn, config, statement_name, sql)
    except OperationalError as exc:
        if exc.http_status_code == 409:
            run_delete(conn, statement_name, quiet=True)
            submit_statement(conn, config, statement_name, sql)
            return
        detail = str(exc)
        if exc.http_status_code is not None:
            detail = f"{detail} (HTTP {exc.http_status_code})"
        print(f"  warning: could not drop {table}: {detail}", file=sys.stderr)
        return
    except RuntimeError as exc:
        print(f"  warning: could not drop {table}: {exc}", file=sys.stderr)
        return
    run_delete(conn, statement_name, quiet=True)


def drop_tables(
    tables: list[str],
    *,
    manifest: DeployManifest,
    config: dict[str, str],
) -> None:
    if not tables:
        return
    print("Dropping tables...")
    with flink_connection(config, user_agent=manifest.user_agent) as conn:
        for table in tables:
            statement_name = manifest.drop_statement_name(table).replace('_', '-')
            run_drop_table(
                conn,
                config,
                table,
                statement_name,
            )


def full_undeploy(
    manifest: DeployManifest,
    *,
    config: dict[str, str],
    drop_tables_after: bool = True,
) -> None:
    """Stop/delete running statements, then drop tables listed in the manifest."""
    statements = manifest.statements_for_full_undeploy()
    if statements:
        print("Stopping and deleting Flink statements...")
        undeploy_statements(statements, config=config, user_agent=manifest.user_agent)
    if drop_tables_after and manifest.drop_tables:
        drop_tables(manifest.drop_tables, manifest=manifest, config=config)
