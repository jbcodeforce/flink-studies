"""
Confluent Platform (CMF) Flink REST API client.

Uses CMF REST API at /cmf/api/v1. No authentication for local CMF.
Config via env: CMF_BASE_URL (default http://localhost:8084), CMF_ENV_NAME (default dev-env),
CMF_COMPUTE_POOL_NAME (default pool1), CMF_CATALOG_NAME, CMF_DATABASE_NAME.
"""

import os
import subprocess
import time

import requests

from tools import cp_flink_utils


def _base_url() -> str:
    return (os.environ.get("CMF_BASE_URL") or "http://localhost:8084").rstrip("/")


def _env_name() -> str:
    return os.environ.get("CMF_ENV_NAME") or "dev-env"


def _compute_pool_name() -> str:
    return os.environ.get("CMF_COMPUTE_POOL_NAME") or "pool1"


def _default_properties() -> dict:
    catalog = os.environ.get("CMF_CATALOG_NAME") or "dev-catalog"
    database = os.environ.get("CMF_DATABASE_NAME") or "kafka-db"
    return {"sql.current-catalog": catalog, "sql.current-database": database}


def cmf_request(
    method: str,
    path: str,
    base_url: str | None = None,
    json_body: dict | None = None,
    timeout: int = 60,
) -> dict:
    """Send request to CMF REST API. path is relative to base (e.g. /cmf/api/v1/environments)."""
    base = (base_url or _base_url()).rstrip("/")
    url = f"{base}{path}" if path.startswith("/") else f"{base}/{path}"
    headers = {"Content-Type": "application/json"}
    resp = requests.request(
        method=method,
        url=url,
        headers=headers,
        json=json_body,
        timeout=timeout,
    )
    if resp.status_code in (200, 201, 202, 204):
        if resp.status_code == 204 or not resp.text:
            return {}
        return resp.json()
    err = resp.text
    try:
        err = resp.json()
    except Exception:
        pass
    raise RuntimeError(f"CMF API {method} {path}: {resp.status_code} {err}")


def get_environments(base_url: str | None = None, timeout: int = 30) -> dict:
    """GET /cmf/api/v1/environments. Returns list response (items in .items or similar)."""
    return cmf_request("GET", "/cmf/api/v1/environments", base_url=base_url, timeout=timeout)


def get_catalogs_kafka(base_url: str | None = None, timeout: int = 30) -> dict:
    """GET /cmf/api/v1/catalogs/kafka. Returns catalog list."""
    return cmf_request("GET", "/cmf/api/v1/catalogs/kafka", base_url=base_url, timeout=timeout)


def ensure_cmf_reachable(
    start_port_forward: bool,
    base_url: str | None = None,
    port_forward_timeout: int = 60,
) -> None:
    """Verify CMF REST is reachable; optionally start kubectl port-forward and wait."""
    base = base_url or _base_url()
    try:
        cmf_request("GET", "/cmf/api/v1/environments", base_url=base, timeout=10)
        print("CMF REST reachable")
        return
    except Exception:
        if not start_port_forward:
            raise RuntimeError(
                f"CMF not reachable at {base}. Start port-forward: "
                "kubectl port-forward svc/cmf-service 8084:80 -n confluent (or make port_forward_cmf)"
            )
    ns = cp_flink_utils.kubectl_ns()
    port = os.environ.get("CMF_PORT_FORWARD_PORT") or "8084"
    print(f"Starting port-forward to cmf-service {port}:80 in {ns}...")
    proc = subprocess.Popen(
        ["kubectl", "port-forward", "svc/cmf-service", f"{port}:80", "-n", ns],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
    )
    deadline = time.monotonic() + port_forward_timeout
    while time.monotonic() < deadline:
        time.sleep(1)
        try:
            cmf_request("GET", "/cmf/api/v1/environments", base_url=base, timeout=5)
            print("CMF REST reachable (port-forward active)")
            return
        except Exception:
            if proc.poll() is not None:
                err = proc.stderr.read().decode() if proc.stderr else ""
                proc.kill()
                raise RuntimeError(f"Port-forward exited: {err}")
    proc.kill()
    raise RuntimeError(f"CMF did not become reachable within {port_forward_timeout}s")


def check_environment(
    env_name: str,
    base_url: str | None = None,
) -> None:
    """Verify the environment exists. Raises RuntimeError if not found."""
    data = get_environments(base_url=base_url)
    items = data.get("items") or data.get("content") or []
    if isinstance(data, list):
        items = data
    names = [x.get("name") for x in items if isinstance(x, dict) and x.get("name")]
    if env_name not in names:
        raise RuntimeError(
            f"Environment '{env_name}' not found. Create it: cd deployment/k8s/cmf && make create_flink_env"
        )
    print(f"Environment {env_name} OK")


def check_catalog(
    catalog_name: str,
    base_url: str | None = None,
) -> None:
    """Verify the Kafka catalog exists. Raises RuntimeError if not found."""
    try:
        data = get_catalogs_kafka(base_url=base_url)
    except RuntimeError as e:
        if "404" in str(e):
            raise RuntimeError(
                "Kafka catalog not found. Create it: cd deployment/k8s/cmf && make create_kafka_catalog"
            ) from e
        raise
    if isinstance(data, dict) and data.get("name") == catalog_name:
        print(f"Catalog {catalog_name} OK")
        return
    items = data.get("items") or data.get("content") or []
    if isinstance(data, list):
        items = data
    names = [
        x.get("metadata", {}).get("name")
        for x in items
        if isinstance(x, dict) and x.get("metadata", {}).get("name") == catalog_name
    ]
    if catalog_name not in names and (isinstance(data, dict) and data.get("name") != catalog_name):
        raise RuntimeError(
            f"Catalog '{catalog_name}' not found. Create it: cd deployment/k8s/cmf && make create_kafka_catalog"
        )
    print(f"Catalog {catalog_name} OK")


def get_compute_pools(
    env_name: str,
    base_url: str | None = None,
    timeout: int = 30,
) -> dict:
    """GET /cmf/api/v1/environments/{env}/compute-pools."""
    return cmf_request(
        "GET",
        f"/cmf/api/v1/environments/{env_name}/compute-pools",
        base_url=base_url,
        timeout=timeout,
    )


def check_compute_pool(
    env_name: str,
    pool_name: str,
    base_url: str | None = None,
) -> None:
    """Verify the compute pool exists in the environment. Raises RuntimeError if not found."""
    data = get_compute_pools(env_name, base_url=base_url)
    items = data.get("items") or data.get("content") or []
    if isinstance(data, list):
        items = data
    names = [
        x.get("metadata", {}).get("name")
        for x in items
        if isinstance(x, dict) and x.get("metadata", {}).get("name") == pool_name
    ]
    if pool_name not in names:
        raise RuntimeError(
            f"Compute pool '{pool_name}' not found in {env_name}. "
            "Create it: cd deployment/k8s/cmf && make create_compute_pool"
        )
    print(f"Compute pool {pool_name} OK")


def get_databases(
    catalog_name: str,
    base_url: str | None = None,
    timeout: int = 30,
) -> dict:
    """GET /cmf/api/v1/catalogs/kafka/{catalog}/databases."""
    return cmf_request(
        "GET",
        f"/cmf/api/v1/catalogs/kafka/{catalog_name}/databases",
        base_url=base_url,
        timeout=timeout,
    )


def create_statement(
    env_name: str,
    name: str,
    sql: str,
    compute_pool_name: str | None = None,
    properties: dict | None = None,
    base_url: str | None = None,
    wait_phase: str | list[str] | None = None,
    poll_interval: int = 5,
    timeout: int = 600,
    stopped: bool = False,
) -> dict:
    """
    Create a Flink SQL statement via CMF. POST /cmf/api/v1/environments/{env}/statements.

    If wait_phase is set, poll until status.phase is in that set (or FAILED/timeout).
    wait_phase can be a single phase (e.g. "COMPLETED") or a list (e.g. ["RUNNING", "COMPLETED"]).
    If phase is FAILED or FAILING and not in wait_phase, raises RuntimeError.
    """
    base = base_url or _base_url()
    pool = compute_pool_name or _compute_pool_name()
    props = {**_default_properties(), **(properties or {})}
    body = {
        "apiVersion": "cmf.confluent.io/v1",
        "kind": "Statement",
        "metadata": {"name": name},
        "spec": {
            "statement": sql,
            "computePoolName": pool,
            "properties": props,
            "stopped": stopped,
        },
    }
    out = cmf_request(
        "POST",
        f"/cmf/api/v1/environments/{env_name}/statements",
        base_url=base,
        json_body=body,
        timeout=120,
    )
    if out.get("errors"):
        raise RuntimeError(out["errors"])

    if not wait_phase:
        return out

    accepted = {wait_phase} if isinstance(wait_phase, str) else set(wait_phase)
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        st = get_statement(env_name, name, base_url=base)
        phase = (st.get("status") or {}).get("phase")
        if phase in accepted:
            return st
        if phase in ("FAILED", "FAILING") and phase not in accepted:
            detail = (st.get("status") or {}).get("detail", "")
            raise RuntimeError(f"Statement {name} {phase}: {detail}")
        time.sleep(poll_interval)
    raise TimeoutError(f"Statement {name} did not reach {accepted} within {timeout}s")


def get_statement(
    env_name: str,
    name: str,
    base_url: str | None = None,
    timeout: int = 30,
) -> dict:
    """GET /cmf/api/v1/environments/{env}/statements/{name}. Returns statement with status.phase."""
    return cmf_request(
        "GET",
        f"/cmf/api/v1/environments/{env_name}/statements/{name}",
        base_url=base_url or _base_url(),
        timeout=timeout,
    )


def get_statement_results(
    env_name: str,
    name: str,
    page_token: str | None = None,
    base_url: str | None = None,
    timeout: int = 60,
) -> dict:
    """
    GET .../statements/{name}/results. Handles pagination via page-token.
    Returns dict with 'results' (list of row arrays) and optional 'metadata'.
    """
    base = base_url or _base_url()
    all_rows = []
    deadline = time.monotonic() + timeout
    next_token = page_token

    while time.monotonic() < deadline:
        path = f"/cmf/api/v1/environments/{env_name}/statements/{name}/results"
        if next_token:
            path = f"{path}?page-token={next_token}"
        data = cmf_request("GET", path, base_url=base, timeout=30)
        if data.get("errors"):
            raise RuntimeError(data["errors"])

        result_block = data.get("result") or data.get("results") or {}
        if isinstance(result_block, dict):
            rows_data = result_block.get("data") or []
        else:
            rows_data = result_block if isinstance(result_block, list) else []
        for r in rows_data:
            if isinstance(r, dict) and "row" in r:
                all_rows.append(r.get("row") or [])
            elif isinstance(r, (list, tuple)):
                all_rows.append(list(r))
            else:
                all_rows.append(r)

        meta = data.get("metadata") or {}
        next_token = meta.get("pageToken") or meta.get("nextPageToken") or meta.get("next")
        if not next_token:
            return {"results": all_rows, "metadata": meta}
        time.sleep(0.5)

    return {"results": all_rows, "metadata": {}}


def delete_statement(
    env_name: str,
    name: str,
    base_url: str | None = None,
    timeout: int = 60,
) -> None:
    """DELETE .../statements/{name}. Idempotent (404 is ignored)."""
    try:
        cmf_request(
            "DELETE",
            f"/cmf/api/v1/environments/{env_name}/statements/{name}",
            base_url=base_url or _base_url(),
            timeout=timeout,
        )
    except RuntimeError as e:
        if "404" not in str(e):
            raise
