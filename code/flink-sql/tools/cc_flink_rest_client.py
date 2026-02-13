"""
Simple Confluent Cloud Flink REST API client.

Loads env vars from a dotenv file by default: ~/.confluent/.env
Override with CONFLUENT_ENV_FILE (path to .env file).

Required env vars (after dotenv):
  FLINK_API_KEY, FLINK_API_SECRET (or CONFLUENT_CLOUD_API_KEY, CONFLUENT_CLOUD_API_SECRET)
  ORGANIZATION_ID, ENVIRONMENT_ID, COMPUTE_POOL_ID
  FLINK_BASE_URL (e.g. https://flink.us-west-2.aws.confluent.cloud)
    or REGION + CLOUD (e.g. us-west-2, aws) to build it.

Optional: DB_NAME (sql.current-database), CATALOG_NAME (sql.current-catalog).
"""

import os
import time
from base64 import b64encode
from pathlib import Path

import requests

# Load dotenv before reading env vars. Default: ~/.confluent/.env (no-op if missing)
from dotenv import load_dotenv
_env_file = os.environ.get("CONFLUENT_ENV_FILE") or str(Path.home() / ".confluent" / ".env")
load_dotenv(_env_file)


def _auth_header() -> str:
    api_key = os.environ.get("FLINK_API_KEY") or os.environ.get("CONFLUENT_CLOUD_API_KEY")
    api_secret = os.environ.get("FLINK_API_SECRET") or os.environ.get("CONFLUENT_CLOUD_API_SECRET")
    if not api_key or not api_secret:
        raise ValueError("Set FLINK_API_KEY and FLINK_API_SECRET (or CONFLUENT_CLOUD_API_KEY/SECRET)")
    creds = f"{api_key}:{api_secret}"
    encoded = b64encode(creds.encode()).decode()
    return f"Basic {encoded}"


def _base_url() -> str:
    url = os.environ.get("FLINK_BASE_URL")
    if url:
        return url.rstrip("/")
    region = os.environ.get("REGION", "us-west-2")
    cloud = os.environ.get("CLOUD", "aws")
    return f"https://flink.{region}.{cloud}.confluent.cloud"


def _flink_url() -> str:
    org_id = os.environ.get("ORGANIZATION_ID") or os.environ.get("FLINK_ORG_ID")
    env_id = os.environ.get("ENVIRONMENT_ID") or  os.environ.get("FLINK_ENV_ID")
    if not org_id or not env_id:
        raise ValueError("Set ORGANIZATION_ID and ENVIRONMENT_ID")
    return f"{_base_url()}/sql/v1/organizations/{org_id}/environments/{env_id}"


def _default_properties() -> dict:
    props = {}
    db = os.environ.get("FLINK_DATABASE_NAME")
    if db:
        props["sql.current-database"] = db
    catalog = os.environ.get("FLINK_ENV_NAME")
    if catalog:
        props["sql.current-catalog"] = catalog
    return props


def request(method: str, path: str, json_body: dict = None, timeout: int = 60) -> dict:
    """Send request to Flink REST API. path is relative to base (e.g. /statements)."""
    url = f"{_flink_url()}{path}" if path.startswith("/") else f"{_flink_url()}/{path}"
    headers = {"Authorization": _auth_header(), "Content-Type": "application/json"}
    print(f"Sending {method} request to {url}")
    print(f"Headers: {headers}")
    print(f"JSON body: {json_body}")
    print(f"Timeout: {timeout}")
    resp = requests.request(
        method=method,
        url=url,
        headers=headers,
        json=json_body,
        timeout=timeout,
    )
    if resp.status_code in (200, 201, 202):
        return resp.json() if resp.text else {}
    err = resp.text
    try:
        err = resp.json()
    except Exception:
        pass
    raise RuntimeError(f"Flink API {method} {path}: {resp.status_code} {err}")


def create_statement(
    name: str,
    sql: str,
    *,
    properties: dict = None,
    stopped: bool = False,
    wait_phase: str | list[str] | None = None,
    poll_interval: int = 5,
    timeout: int = 600,
) -> dict:
    """
    Create a Flink SQL statement. Returns the statement object.

    If wait_phase is set, poll until status.phase is in that set (or FAILED/timeout).
    wait_phase can be a single phase (e.g. "COMPLETED") or a list (e.g. ["RUNNING", "COMPLETED"]).
    If phase is FAILED or FAILING and not in wait_phase, raises RuntimeError.
    """
    org_id = os.environ.get("ORGANIZATION_ID")
    env_id = os.environ.get("ENVIRONMENT_ID")
    cpool_id = os.environ.get("COMPUTE_POOL_ID") or os.environ.get("FLINK_COMPUTE_POOL_ID")
    if not cpool_id:
        raise ValueError("Set COMPUTE_POOL_ID or FLINK_COMPUTE_POOL_ID")

    props = {**_default_properties(), **(properties or {})}
    body = {
        "name": name,
        "organization_id": org_id,
        "environment_id": env_id,
        "spec": {
            "statement": sql,
            "properties": props,
            "compute_pool_id": cpool_id,
            "stopped": stopped,
        },
    }
    out = request("POST", "/statements", json_body=body, timeout=120)
    if out.get("errors"):
        raise RuntimeError(out["errors"])

    if not wait_phase:
        return out

    accepted = {wait_phase} if isinstance(wait_phase, str) else set(wait_phase)
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        st = get_statement(name)
        phase = (st.get("status") or {}).get("phase")
        if phase in accepted:
            return st
        if phase in ("FAILED", "FAILING") and phase not in accepted:
            detail = (st.get("status") or {}).get("detail", "")
            raise RuntimeError(f"Statement {name} {phase}: {detail}")
        time.sleep(poll_interval)
    raise TimeoutError(f"Statement {name} did not reach {accepted} within {timeout}s")


def get_statement(name: str) -> dict:
    """Get a statement by name."""
    return request("GET", f"/statements/{name}")


def _get_url(url: str, timeout: int = 30) -> dict:
    """GET by full URL (for pagination next link)."""
    resp = requests.get(
        url,
        headers={"Authorization": _auth_header(), "Content-Type": "application/json"},
        timeout=timeout,
    )
    if resp.status_code != 200:
        raise RuntimeError(f"GET {url}: {resp.status_code} {resp.text}")
    return resp.json() if resp.text else {}


def get_statement_results(name: str, timeout: int = 60) -> dict:
    """
    Get statement results (e.g. for snapshot query). Handles pagination via metadata.next.
    Returns dict with 'results' (list of row arrays) and optional 'metadata'.
    """
    url_path = f"/statements/{name}/results"
    all_rows = []
    next_url = None
    deadline = time.monotonic() + timeout

    while time.monotonic() < deadline:
        if next_url:
            data = _get_url(next_url, timeout=30)
        else:
            data = request("GET", url_path, timeout=30)

        if data.get("errors"):
            raise RuntimeError(data["errors"])

        results = data.get("results") or {}
        rows = results.get("data") or []
        for r in rows:
            all_rows.append(r.get("row") or [])

        meta = data.get("metadata") or {}
        next_url = meta.get("next")
        if not next_url:
            return {"results": all_rows, "metadata": meta}
        time.sleep(1)

    return {"results": all_rows, "metadata": {}}


def delete_statement(name: str, timeout: int = 60) -> None:
    """Delete a statement by name. Idempotent (404 is ignored)."""
    try:
        request("DELETE", f"/statements/{name}", timeout=timeout)
    except RuntimeError as e:
        if "404" not in str(e):
            raise
