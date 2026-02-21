"""
Confluent Platform Flink (CMF) utility helpers.

Uses KUBECTL_NAMESPACE (default: confluent) for kubectl operations.
"""

import os
import subprocess

# Pod name prefixes that must be Running in the target namespace
REQUIRED_POD_PREFIXES = [
    "confluent-manager-for-apache-flink",
    "kafka-",
    "schemaregistry-",
]


def kubectl_ns() -> str:
    """Return Kubernetes namespace for CP resources (env KUBECTL_NAMESPACE or 'confluent')."""
    return os.environ.get("KUBECTL_NAMESPACE") or "confluent"


def check_pods(skip: bool) -> None:
    """Verify required CP Flink pods are Running in the namespace. Raises on failure."""
    if skip:
        return
    ns = kubectl_ns()
    try:
        out = subprocess.run(
            ["kubectl", "get", "pods", "-n", ns, "-o", "wide"],
            capture_output=True,
            text=True,
            timeout=15,
        )
    except FileNotFoundError:
        raise RuntimeError("kubectl not found; install kubectl or use --skip-kubectl")
    if out.returncode != 0:
        raise RuntimeError(f"kubectl get pods failed: {out.stderr or out.stdout}")
    lines = [l for l in out.stdout.strip().splitlines() if l]
    if len(lines) < 2:
        raise RuntimeError(
            f"No pods in namespace {ns}; start CP Flink first (see deployment/k8s/cmf)"
        )
    running_by_prefix = {}
    for line in lines[1:]:
        parts = line.split()
        if len(parts) < 3:
            continue
        name, ready, status = parts[0], parts[1], parts[2]
        for prefix in REQUIRED_POD_PREFIXES:
            if name.startswith(prefix) or (prefix.endswith("-") and name.startswith(prefix)):
                if status == "Running" and ready and ready.split("/")[0] == ready.split("/")[-1]:
                    running_by_prefix[prefix] = running_by_prefix.get(prefix, 0) + 1
                break
    missing = [p for p in REQUIRED_POD_PREFIXES if not running_by_prefix.get(p)]
    if missing:
        raise RuntimeError(
            f"Expected pods Running in {ns}: {REQUIRED_POD_PREFIXES}. Missing or not Running: {missing}. "
            "Run: kubectl get pods -n confluent"
        )
    print("Pods check OK")
