---
name: e2e-demo-structure
description: Define and apply the standard layout for e2e-demos: deployment folders (cc, oss-flink, cp-flink), README requirements, and automation (IaC + app logic). Use when creating or refactoring demos under e2e-demos/.
---

# E2E-demo standard structure

Apply this layout when creating or refactoring any demo under `e2e-demos/`.

## 1. Standard folder layout

**Root of each demo**

- `README.md` – Demo-level: business goal, use cases, high-level architecture. List which deployment types are supported and link to their folders.
- Optional shared assets (`sql-scripts/`, `tests/`, `schemas/`) only if truly shared across all deployment types; otherwise keep deployment-specific assets inside the deployment folders.

**Deployment folders** (create only the ones the demo supports)

- **`cc/`** – Confluent Cloud: Terraform and Confluent-specific config, Flink SQL/workspace assets, scripts to deploy/run on CC (e.g. Confluent CLI, `deploy_flink_statements.py`). Use subfolders such as `cc/IaC/`, `cc/flink-sql/` when useful.
- **`oss-flink/`** – OSS Apache Flink: Docker Compose, plain K8s (non-Confluent), or SQL client / Flink job artifacts. How to run against vanilla Flink + Kafka (or equivalent).
- **`cp-flink/`** – Confluent Platform Flink: K8s (CMF/CFK/FKO), FlinkApplication CRDs, Table API/Java if used, Confluent Platform–specific configs and scripts.

## 2. README requirements (per deployment folder)

Each of `cc/`, `oss-flink/`, `cp-flink/` must have a **`README.md`** with at least:

- **Goal** – What this deployment variant demonstrates.
- **Status** – Current state (e.g. "Ready", "WIP", "Not maintained", "Requires CC environment").
- **Implementation approach** – Brief: Terraform vs K8s vs Docker, where Flink SQL vs Table API lives, how UDFs/tests are wired.
- **How to run** – Prerequisites, env vars, ordered steps (e.g. 1. Apply IaC, 2. Deploy Flink statements, 3. Run producer / tests). Prefer one-command where possible (e.g. `make demo` or `./run_demo.sh`).

## 3. Automation

- **IaC:** One place per deployment type (e.g. `cc/IaC/` for Terraform). Standardize on `IaC/` inside the deployment folder; avoid mixed names like `IaC-for-CC` across demos.
- **Application logic:** Scripts or Makefile targets to deploy Flink DDL/DML, run producers, run validation (e.g. `run_tests.sh`, `make validate`). Document in the deployment folder README.
- **Split:** Two phases are preferred: (1) apply IaC to get Kafka/Flink/environment, (2) run application steps (deploy statements, data, validate). Both should be documented and scripted where feasible.

## 4. Naming and references

- Use consistent names: `README.md` (capitalized), `sql-scripts/` or deployment-specific equivalent, `tests/` for insert/validate SQL or test definitions.
- The root `e2e-demos/README.md` should index demos and reference deployment folders (e.g. "CC: `demo-name/cc/`", "CP: `demo-name/cp-flink/`").

## 5. When a deployment type does not apply

- Do not create an empty folder. In the demo root README, state which deployment types are supported and link only to the folders that exist.
