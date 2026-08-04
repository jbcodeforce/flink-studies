"""
Library API for Confluent Cloud Flink statement lifecycle via confluent-sql.

No print / sys.exit — callers (CLI wrappers, flink-skill-common) own UX.
"""

from __future__ import annotations

import json
import os
import time
from collections.abc import Callable
from typing import Any

from confluent_sql.exceptions import OperationalError, StatementNotFoundError

POLL_INTERVAL_SEC = float(os.environ.get("FLINK_POLL_INTERVAL", "5"))
STATEMENT_TIMEOUT_SEC = int(os.environ.get("FLINK_STATEMENT_TIMEOUT", "600"))

SUCCESS_PHASES = frozenset({"RUNNING", "COMPLETED", "STOPPED", "DELETED"})
FAILURE_PHASES = frozenset({"FAILED", "FAILING"})

SleepFn = Callable[[float], None]


class StatementLifecycleError(RuntimeError):
    """Flink statement lifecycle operation failed."""


def classify_sql(sql: str) -> str:
    """Classify SQL for the correct confluent-sql execution path."""
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
        return "streaming_ddl"
    if s.startswith(("create table ", "drop table ")):
        return "snapshot_ddl"
    return "snapshot_ddl"


def statement_properties(config: dict[str, str]) -> dict[str, str]:
    """Extra statement properties (catalog/database overrides currently unused)."""
    _ = config
    return {}


def _phase_from_stmt(stmt: Any) -> str:
    status = getattr(stmt, "status", None)
    if isinstance(status, dict) and status.get("phase") is not None:
        return str(status["phase"])
    phase = getattr(stmt, "phase", None)
    if phase is not None:
        name = getattr(phase, "name", None)
        if name is not None:
            return str(name)
        return str(phase)
    return "UNKNOWN"


def _detail_from_stmt(stmt: Any) -> str:
    status = getattr(stmt, "status", None)
    if isinstance(status, dict):
        return str(status.get("detail", ""))
    return ""


def statement_status(conn: Any, statement_name: str) -> dict[str, Any]:
    """Return normalized statement status (phase/detail); NOT_FOUND if missing."""
    try:
        stmt = conn.get_statement(statement_name)
    except StatementNotFoundError:
        return {
            "name": statement_name,
            "phase": "NOT_FOUND",
            "detail": "Statement not found",
        }
    return {
        "name": statement_name,
        "phase": _phase_from_stmt(stmt),
        "detail": _detail_from_stmt(stmt),
    }


def list_statements(conn: Any, page_size: int = 50) -> dict[str, Any]:
    """List Flink statements (first REST page)."""
    resp = conn._request(  # noqa: SLF001
        "/statements",
        params={"page_size": page_size},
    )
    payload = resp.json() if hasattr(resp, "json") else {}
    items = payload.get("data") if isinstance(payload, dict) else payload
    if not isinstance(items, list):
        items = []
    normalized = []
    for item in items:
        if not isinstance(item, dict):
            continue
        status = item.get("status") or {}
        normalized.append(
            {
                "name": item.get("name") or item.get("statementName") or "",
                "phase": status.get("phase", "UNKNOWN"),
                "detail": status.get("detail", ""),
            }
        )
    return {"statements": normalized, "count": len(normalized)}


def get_statement_exceptions(conn: Any, statement_name: str) -> dict[str, Any]:
    """Fetch recent exceptions for a statement via Flink REST."""
    resp = conn._request(  # noqa: SLF001
        f"/statements/{statement_name}/exceptions",
        method="GET",
        raise_for_status=False,
    )
    status = getattr(resp, "status_code", 200)
    if status == 404:
        return {"name": statement_name, "exceptions": []}
    if isinstance(status, int) and status >= 400:
        return {
            "name": statement_name,
            "error": f"HTTP {status}",
            "body": getattr(resp, "text", str(resp)),
        }
    try:
        return resp.json()
    except Exception:
        return {"name": statement_name, "raw": str(resp)}


def check_statement_health(
    conn: Any,
    statement_name: str,
    *,
    success_phases: frozenset[str] | set[str] = SUCCESS_PHASES,
) -> dict[str, Any]:
    """Simple health summary from statement phase."""
    status = statement_status(conn, statement_name)
    phase = status.get("phase", "UNKNOWN")
    return {
        "statement_name": statement_name,
        "phase": phase,
        "healthy": phase in success_phases,
        "detail": status.get("detail", ""),
    }


def submit_statement(
    conn: Any,
    config: dict[str, str],
    name: str,
    sql: str,
    *,
    dry_run: bool = False,
    timeout: float | None = None,
) -> dict[str, Any]:
    """
    Submit SQL as a Flink statement.

    Returns status dict with name, phase, detail, kind.
    dry_run=True sets sql.dry-run for validation-only submits.
    """
    props = dict(statement_properties(config))
    if dry_run:
        props["sql.dry-run"] = "true"
        props["sql.inline-result"] = "false"

    kind = classify_sql(sql)
    pool = config["FLINK_COMPUTE_POOL_ID"]
    timeout_sec = int(timeout if timeout is not None else STATEMENT_TIMEOUT_SEC)

    if kind == "snapshot_ddl":
        stmt = conn.execute_snapshot_ddl(
            sql,
            statement_name=name,
            properties=props,
            compute_pool_id=pool,
            timeout=timeout_sec,
        )
    elif kind in ("streaming_dml", "batch_dml", "streaming_ddl"):
        with conn.closing_streaming_cursor() as cur:
            cur.execute(
                sql,
                statement_name=name,
                properties=props,
                compute_pool_id=pool,
                timeout=timeout_sec,
            )
            stmt = cur.statement
    else:
        raise StatementLifecycleError(f"Unsupported SQL kind for {name}: {kind}")

    return {
        "name": name,
        "phase": _phase_from_stmt(stmt),
        "detail": _detail_from_stmt(stmt),
        "kind": kind,
    }


def delete_statement(
    conn: Any,
    statement_name: str,
    *,
    timeout: float | None = None,
    poll: float | None = None,
    sleep: SleepFn = time.sleep,
) -> dict[str, Any]:
    """Delete a statement and wait until it is gone."""
    try:
        conn.delete_statement(statement_name)
    except StatementNotFoundError:
        return {"name": statement_name, "status": "not_found"}

    deadline = time.monotonic() + (timeout if timeout is not None else STATEMENT_TIMEOUT_SEC)
    poll_sec = poll if poll is not None else POLL_INTERVAL_SEC
    while time.monotonic() < deadline:
        try:
            conn.get_statement(statement_name)
        except StatementNotFoundError:
            return {"name": statement_name, "status": "deleted"}
        sleep(poll_sec)

    raise StatementLifecycleError(
        f"Statement {statement_name} still present after delete timeout"
    )


def create_statement(
    conn: Any,
    config: dict[str, str],
    name: str,
    sql: str,
    *,
    dry_run: bool = False,
    timeout: float | None = None,
    poll: float | None = None,
    sleep: SleepFn = time.sleep,
) -> dict[str, Any]:
    """Create a Flink statement; on 409 conflict delete and retry once."""
    timeout_sec = timeout if timeout is not None else float(STATEMENT_TIMEOUT_SEC)
    poll_sec = poll if poll is not None else POLL_INTERVAL_SEC

    try:
        return submit_statement(
            conn, config, name, sql, dry_run=dry_run, timeout=timeout_sec
        )
    except OperationalError as exc:
        if exc.http_status_code != 409:
            detail = str(exc)
            if exc.http_status_code is not None:
                detail = f"{detail} (HTTP {exc.http_status_code})"
            raise StatementLifecycleError(f"Failed to create {name}: {detail}") from exc

        try:
            conn.delete_statement(name)
        except StatementNotFoundError:
            pass

        deadline = time.monotonic() + timeout_sec
        while time.monotonic() < deadline:
            try:
                conn.get_statement(name)
                sleep(poll_sec)
            except StatementNotFoundError:
                break
        else:
            raise StatementLifecycleError(
                f"Statement {name} still exists after delete before retry"
            )

        return submit_statement(
            conn, config, name, sql, dry_run=dry_run, timeout=timeout_sec
        )


def wait_for_phase(
    conn: Any,
    statement_name: str,
    accepted_phases: set[str] | frozenset[str],
    *,
    timeout: float | None = None,
    poll: float | None = None,
    sleep: SleepFn = time.sleep,
    treat_failure_as_terminal: bool = True,
) -> dict[str, Any]:
    """
    Poll until statement reaches an accepted phase (or failure/NOT_FOUND).

    Returns the last status dict. Does not raise on FAILED when
    treat_failure_as_terminal is True — caller inspects phase.
    """
    deadline = time.monotonic() + (timeout if timeout is not None else STATEMENT_TIMEOUT_SEC)
    poll_sec = poll if poll is not None else POLL_INTERVAL_SEC
    last: dict[str, Any] = {}

    while time.monotonic() < deadline:
        last = statement_status(conn, statement_name)
        phase = last.get("phase", "UNKNOWN")
        if phase in accepted_phases:
            return last
        if treat_failure_as_terminal and (
            phase in FAILURE_PHASES or phase == "NOT_FOUND"
        ):
            return last
        sleep(poll_sec)

    raise StatementLifecycleError(
        f"Timeout waiting for {statement_name}; last status: {json.dumps(last)}"
    )


def drop_table(
    conn: Any,
    config: dict[str, str],
    table: str,
    statement_name: str,
    *,
    timeout: float | None = None,
    poll: float | None = None,
    sleep: SleepFn = time.sleep,
) -> None:
    """Submit DROP TABLE IF EXISTS and delete the ephemeral statement."""
    sql = f"DROP TABLE IF EXISTS `{table}`"
    create_statement(
        conn,
        config,
        statement_name,
        sql,
        timeout=timeout,
        poll=poll,
        sleep=sleep,
    )
    delete_statement(
        conn,
        statement_name,
        timeout=timeout,
        poll=poll,
        sleep=sleep,
    )
