# Plan: Skill — `flink-version-bump`

## Overview

Create a Bob skill that guides the agent through auditing and updating Flink /
Confluent Platform / Kafka version references scattered across the repo, and
optionally introduces a centralized version manifest so future bumps touch one file.

Currently versions are pinned in at least 6 different file types with no single
source of truth — `docker-compose.yaml` (CP 7.8.0), `pom.xml` properties
(`flink-version` 1.19.1 or 1.20.2-cp1), root `pyproject.toml` (apache-flink 1.20.1),
`deployment/k8s/Makefile` variables, and inline strings in docs markdown.
This causes silent drift where Docker, Java, and docs reference different versions.

**Scope**: Bob skill SKILL.md file only.

---

## Sub-Tasks

---

### Sub-Task 1 — Map every version pin location

**Intent**: Build the complete, accurate inventory of version pin locations that the
skill will encode. This becomes the "checklist" the skill gives to the agent on every
version bump.

**Expected Outcomes**:
- Complete table: file path → component → current version → how it is expressed
  (image tag, Maven property, pip constraint, Makefile variable, inline doc string).
- Connector version coupling rules noted (e.g. `flink-sql-connector-kafka` version
  must match Flink version).
- OSS vs Confluent Platform variant distinction documented.

**Todo List**:
1. Grep all `docker-compose*.yaml` files under `deployment/docker/` for image tags
   containing `flink`, `kafka`, `confluentinc/cp-`, `schema-registry`.
2. Grep all `pom.xml` files repo-wide for `<flink-version>`, `<flink.version>`,
   `<kafka.version>`, `<confluent-plugin.version>`.
3. Read root `pyproject.toml` and `code/flink-sql/tools/pyproject.toml` for version
   constraints.
4. Read `deployment/k8s/Makefile` for `FLINK_OPERATOR_VERSION` and `CERT_MGR_VERSION`.
5. Grep `docs/**/*.md` for inline version strings (`flink-\d+\.\d+`, `kafka_\d+\.\d+`,
   `cp-\d+\.\d+`, `7\.8`, `1\.20`, `1\.19`).
6. Produce the full inventory table.

**Relevant Context**:
- `deployment/docker/docker-compose.yaml` — CP 7.8.0
- `deployment/docker/kafka-docker-compose.yaml` — Flink 1.20.0, Kafka 3.7.1
- `code/flink-java/my-flink/pom.xml` — flink-version 1.19.1
- `e2e-demos/external-lookup/cp-flink/flink-app/pom.xml` — flink.version 1.20.2-cp1
- `pyproject.toml` (root) — apache-flink==1.20.1
- `deployment/k8s/Makefile` — FLINK_OPERATOR_VERSION=1.11.0, CERT_MGR_VERSION=v1.18.2
- `docs/coding/getting-started.md` — inline 1.20.0, 2.1.1, 3.9.0

**Status**: [ ] pending

---

### Sub-Task 2 — Write the SKILL.md

**Intent**: Author the skill so Bob can execute a structured version-bump pass:
audit current pins, check for newer versions, produce a change plan, and apply
updates in the correct order.

**Expected Outcomes**:
- `~/.bob/skills/flink-version-bump/SKILL.md` exists.
- Skill triggers when user asks to update Flink version, bump CP version, check
  version consistency, or do a quarterly version update.
- Skill produces an audit report and an ordered change plan before touching any files.

**Todo List**:
1. Create directory `~/.bob/skills/flink-version-bump/`.
2. Write `SKILL.md` with frontmatter (`name`, `description`, `triggers`).
3. Document **Phase 1 — audit**: run the grep inventory from Sub-Task 1 steps 1–5.
   Present results as a table. Ask the user to confirm the target new versions before
   proceeding.
4. Document **Phase 2 — version compatibility check** rules:
   - `flink-sql-connector-kafka` version must match the Flink minor version
     (e.g. Flink 1.20 → connector `3.x.0-1.20`).
   - CP Flink variant (`1.20.2-cp1`) differs from OSS Flink — do not cross-substitute.
   - Flink Kubernetes Operator version has its own release cadence; check
     https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-stable/.
   - Python `apache-flink` version must match the OSS Flink cluster version.
5. Document **Phase 3 — ordered change plan** (infrastructure before code, code before
   docs):
   1. `deployment/docker/` compose files (image tags)
   2. `deployment/k8s/Makefile` (operator + cert-manager versions)
   3. `code/flink-java/*/pom.xml` and `e2e-demos/*/pom.xml` (Maven properties)
   4. Root `pyproject.toml` (Python constraint)
   5. `docs/coding/getting-started.md` and other doc inline strings
6. Document **Phase 4 — apply changes**: for each file in the plan, use
   `search_and_replace` targeting the exact version string (not a broad regex that
   could hit comments).
7. Document **Phase 5 — optional centralized manifest**: if the user wants a single
   source of truth, create `deployment/versions.env` with variables:
   ```env
   FLINK_VERSION=1.20.2
   CP_VERSION=7.8.0
   FLINK_OPERATOR_VERSION=1.11.0
   CERT_MGR_VERSION=v1.18.2
   ```
   and note which files could source this file vs. which require manual sync
   (Maven pom.xml cannot source an env file directly).
8. Document **security reminder**: per repo security policy, never pin to EOL or
   extended-support-only versions; check the
   [Apache Flink release notes](https://flink.apache.org/downloads/) for active
   support status before selecting a target version.
9. Note known version variants in this repo:
   - **OSS Flink** (`apache/flink:1.x.y`) — used in Docker Compose + Python
   - **Confluent Platform Flink** (`1.x.y-cp1`) — used in CP K8s demos and some pom.xml
   - Bumping one does NOT imply bumping the other.

**Relevant Context**:
- `deployment/docker/` — Docker Compose files
- `deployment/k8s/Makefile` — K8s operator versions
- `code/flink-java/my-flink/pom.xml` and `e2e-demos/*/pom.xml` — Maven projects
- `pyproject.toml` (root) — Python Flink dependency
- `docs/coding/getting-started.md`, `docs/coding/k8s-deploy.md` — doc inline versions

**Status**: [ ] pending

---

### Sub-Task 3 — Register the skill with Bob

**Intent**: Make the skill discoverable.

**Expected Outcomes**:
- Skill appears in Bob's available skills list under `flink-version-bump`.

**Todo List**:
1. Confirm file path matches Bob's convention (`~/.bob/skills/<skill-name>/SKILL.md`).
2. Verify skill loads correctly via `use_skill`.

**Status**: [ ] pending

---
