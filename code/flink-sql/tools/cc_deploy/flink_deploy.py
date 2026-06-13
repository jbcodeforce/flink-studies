"""
Deploy, undeploy, snapshot, and streaming Flink SQL on Confluent Cloud via confluent-sql.

Reusable from demo folders: point at a SQL directory and a deploy manifest (JSON).
Snapshot queries use SNAPSHOT cursor mode (`sql.snapshot.mode = now` is set by the driver).
"""

from __future__ import annotations

import json
import os
import re
import sys
import time
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, Literal

import confluent_sql
from confluent_sql.exceptions import OperationalError, StatementNotFoundError
from dotenv import load_dotenv

from cc_deploy.manifest import (
    DEFAULT_MANIFEST,
    DEFAULT_USER_AGENT,
    DeployManifest,
    StatementRef,
    load_manifest,
)

POLL_INTERVAL_SEC = float(os.environ.get("FLINK_POLL_INTERVAL", "5"))
STATEMENT_TIMEOUT_SEC = int(os.environ.get("FLINK_STATEMENT_TIMEOUT", "600"))


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


OutputFormat = Literal["table", "json", "csv"]


@dataclass(frozen=True)
class SnapshotQueryResult:
    """Rows and metadata from a completed snapshot query."""

    statement_name: str
    sql: str
    columns: list[str]
    rows: list[tuple | dict[str, Any]]
    rowcount: int
    elapsed_sec: float


def _sanitize_statement_name(table_or_label: str) -> str:
    """Build a Flink statement name safe for the REST API."""
    safe = re.sub(r"[^a-zA-Z0-9-]", "-", table_or_label.strip().lower())
    safe = re.sub(r"-+", "-", safe).strip("-")
    return safe[:48] or "table"


def build_select_sql(
    table: str,
    *,
    columns: str = "*",
    limit: int | None = None,
    where: str | None = None,
) -> str:
    """Build a SELECT statement for snapshot execution against a table."""
    table = table.strip()
    if not table:
        raise ValueError("table name is required")

    sql = f"SELECT {columns} FROM {table}"
    if where:
        sql = f"{sql} WHERE {where.strip()}"
    if limit is not None:
        if limit <= 0:
            raise ValueError("limit must be a positive integer")
        sql = f"{sql} LIMIT {limit}"
    return sql


def default_snapshot_statement_name(table: str) -> str:
    """Ephemeral statement name for a snapshot query."""
    stamp = time.strftime("%Y%m%d%H%M%S")
    return f"snapshot-{_sanitize_statement_name(table)}-{stamp}"


def run_snapshot_query(
    sql: str,
    *,
    config: dict[str, str] | None = None,
    statement_name: str | None = None,
    as_dict: bool = False,
    timeout: int = STATEMENT_TIMEOUT_SEC,
    user_agent: str = DEFAULT_USER_AGENT,
    delete_statement: bool = True,
) -> SnapshotQueryResult:
    """
    Execute a snapshot query and return all rows.

    Uses confluent-sql SNAPSHOT cursor mode so the driver sets
    `sql.snapshot.mode = now` and waits for the statement to complete
    before fetching results.
    """
    sql = sql.strip()
    if not sql:
        raise ValueError("sql is required")

    cfg = config or get_config()
    name = statement_name or default_snapshot_statement_name("query")
    props = statement_properties(cfg)
    pool = cfg["FLINK_COMPUTE_POOL_ID"]

    started = time.monotonic()
    description: list[tuple] = []
    rows: list[tuple | dict[str, Any]] = []
    with flink_connection(cfg, user_agent=user_agent) as conn:
        with conn.closing_cursor(as_dict=as_dict) as cur:
            try:
                cur.execute(
                    sql,
                    statement_name=name,
                    properties=props,
                    compute_pool_id=pool,
                    timeout=timeout,
                )
                description = cur.description or []
                rows = cur.fetchall()
            except OperationalError as exc:
                detail = str(exc)
                if exc.http_status_code is not None:
                    detail = f"{detail} (HTTP {exc.http_status_code})"
                raise RuntimeError(f"Snapshot query failed: {detail}") from exc
            finally:
                if delete_statement and not cur.is_closed:
                    try:
                        cur.delete_statement()
                    except OperationalError:
                        pass

    columns = [col[0] for col in description]
    elapsed = time.monotonic() - started
    return SnapshotQueryResult(
        statement_name=name,
        sql=sql,
        columns=columns,
        rows=rows,
        rowcount=len(rows),
        elapsed_sec=elapsed,
    )


def format_snapshot_rows(
    result: SnapshotQueryResult,
    *,
    output: OutputFormat = "table",
) -> str:
    """Format snapshot query rows for stdout."""
    if output == "json":
        if result.rows and isinstance(result.rows[0], dict):
            payload = result.rows
        else:
            payload = [dict(zip(result.columns, row, strict=False)) for row in result.rows]
        return json.dumps(payload, indent=2, default=str)

    if output == "csv":
        lines = []
        if result.columns:
            lines.append(",".join(_csv_escape(col) for col in result.columns))
        for row in result.rows:
            if isinstance(row, dict):
                values = [row.get(col) for col in result.columns]
            else:
                values = list(row)
            lines.append(",".join(_csv_escape(value) for value in values))
        return "\n".join(lines)

    return _format_snapshot_table(result.columns, result.rows)


def print_snapshot_result(
    result: SnapshotQueryResult,
    *,
    output: OutputFormat = "table",
    show_meta: bool = True,
) -> None:
    """Print snapshot query output and optional metadata."""
    if show_meta:
        print(
            f"Statement: {result.statement_name} | "
            f"rows: {result.rowcount} | "
            f"elapsed: {result.elapsed_sec:.2f}s",
            file=sys.stderr,
        )
        print(f"SQL: {result.sql}", file=sys.stderr)

    body = format_snapshot_rows(result, output=output)
    if body:
        print(body)


def _csv_escape(value: Any) -> str:
    if value is None:
        return ""
    text = str(value)
    if any(ch in text for ch in (",", '"', "\n", "\r")):
        return '"' + text.replace('"', '""') + '"'
    return text


def _format_snapshot_table(columns: list[str], rows: Iterable[tuple | dict[str, Any]]) -> str:
    materialized = list(rows)
    if not materialized:
        return ""

    if isinstance(materialized[0], dict):
        col_names = columns or list(materialized[0].keys())
        values = [[str(row.get(col, "")) for col in col_names] for row in materialized]
    else:
        col_names = columns or [f"col{i + 1}" for i in range(len(materialized[0]))]
        values = [[str(cell) for cell in row] for row in materialized]

    widths = [len(name) for name in col_names]
    for row in values:
        for idx, cell in enumerate(row):
            widths[idx] = max(widths[idx], len(cell))

    header = " | ".join(name.ljust(widths[idx]) for idx, name in enumerate(col_names))
    divider = "-+-".join("-" * width for width in widths)
    body = "\n".join(" | ".join(cell.ljust(widths[idx]) for idx, cell in enumerate(row)) for row in values)
    return f"{header}\n{divider}\n{body}"


@dataclass(frozen=True)
class StreamingQueryStats:
    """Summary after a streaming query stops."""

    statement_name: str
    sql: str
    columns: list[str]
    rowcount: int
    elapsed_sec: float
    returns_changelog: bool


def default_streaming_statement_name(table: str) -> str:
    """Ephemeral statement name for a streaming query."""
    stamp = time.strftime("%Y%m%d%H%M%S")
    return f"stream-{_sanitize_statement_name(table)}-{stamp}"


def format_streaming_row(
    row: Any,
    *,
    columns: list[str] | None = None,
    output: OutputFormat = "table",
    returns_changelog: bool = False,
) -> str:
    """Format one streaming row for stdout."""
    op_label: str | None = None
    data = row
    if returns_changelog:
        op_label = str(row.op)
        data = row.row

    if isinstance(data, dict):
        col_names = columns or list(data.keys())
        values = [data.get(col) for col in col_names]
    else:
        values = list(data)

    if output == "json":
        if isinstance(data, dict):
            row_payload: Any = data
        elif columns:
            row_payload = dict(zip(columns, values, strict=False))
        else:
            row_payload = values
        if op_label is not None:
            return json.dumps({"op": op_label, "row": row_payload}, default=str)
        return json.dumps(row_payload, default=str)

    if output == "csv":
        rendered = ([op_label] if op_label else []) + [str(value) for value in values]
        return ",".join(_csv_escape(value) for value in rendered)

    rendered = " | ".join(str(value) for value in values)
    if op_label:
        return f"{op_label} | {rendered}"
    return rendered


def run_streaming_query(
    sql: str,
    *,
    config: dict[str, str] | None = None,
    statement_name: str | None = None,
    as_dict: bool = False,
    timeout: int = STATEMENT_TIMEOUT_SEC,
    user_agent: str = DEFAULT_USER_AGENT,
    output: OutputFormat = "table",
    max_rows: int | None = None,
    show_meta: bool = True,
    delete_statement: bool = True,
    out=None,
) -> StreamingQueryStats:
    """
    Execute a streaming query and print rows as they arrive.

    Blocks on each row until Ctrl+C, max_rows is reached, or the stream ends.
    Uses confluent-sql STREAMING_QUERY cursor mode (unbounded, no snapshot mode).
    """
    sql = sql.strip()
    if not sql:
        raise ValueError("sql is required")
    if max_rows is not None and max_rows <= 0:
        raise ValueError("max_rows must be a positive integer")

    cfg = config or get_config()
    name = statement_name or default_streaming_statement_name("query")
    props = statement_properties(cfg)
    pool = cfg["FLINK_COMPUTE_POOL_ID"]
    sink = out if out is not None else sys.stdout

    started = time.monotonic()
    rowcount = 0
    columns: list[str] = []
    returns_changelog = False
    csv_header_printed = False

    with flink_connection(cfg, user_agent=user_agent) as conn:
        cur = conn.streaming_cursor(as_dict=as_dict)
        try:
            try:
                cur.execute(
                    sql,
                    statement_name=name,
                    properties=props,
                    compute_pool_id=pool,
                    timeout=timeout,
                )
            except OperationalError as exc:
                detail = str(exc)
                if exc.http_status_code is not None:
                    detail = f"{detail} (HTTP {exc.http_status_code})"
                raise RuntimeError(f"Streaming query failed: {detail}") from exc

            columns = [col[0] for col in (cur.description or [])]
            returns_changelog = cur.returns_changelog

            if show_meta:
                print(f"Statement: {name}", file=sys.stderr)
                print(f"SQL: {sql}", file=sys.stderr)
                print("Streaming results (Ctrl+C to stop)...", file=sys.stderr)

            try:
                for row in cur:
                    if output == "csv" and not csv_header_printed:
                        header_cols = (["op"] if returns_changelog else []) + columns
                        if header_cols:
                            print(
                                ",".join(_csv_escape(col) for col in header_cols),
                                file=sink,
                                flush=True,
                            )
                            csv_header_printed = True

                    print(
                        format_streaming_row(
                            row,
                            columns=columns,
                            output=output,
                            returns_changelog=returns_changelog,
                        ),
                        file=sink,
                        flush=True,
                    )
                    rowcount += 1
                    if max_rows is not None and rowcount >= max_rows:
                        if show_meta:
                            print(f"Reached max_rows={max_rows}.", file=sys.stderr)
                        break
            except KeyboardInterrupt:
                if show_meta:
                    print("\nStreaming query stopped.", file=sys.stderr)
        finally:
            if delete_statement and not cur.is_closed:
                try:
                    cur.delete_statement()
                except OperationalError:
                    pass
            cur.close()

    elapsed = time.monotonic() - started
    if show_meta:
        print(
            f"Rows printed: {rowcount} | elapsed: {elapsed:.2f}s",
            file=sys.stderr,
        )

    return StreamingQueryStats(
        statement_name=name,
        sql=sql,
        columns=columns,
        rowcount=rowcount,
        elapsed_sec=elapsed,
        returns_changelog=returns_changelog,
    )
