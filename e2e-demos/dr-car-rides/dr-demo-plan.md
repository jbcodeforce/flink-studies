# Disaster Recovery (Car Rides) Demonstration Plan & Status

**Status: COMPLETED**

## Top-Level Overview
Finalize the `e2e-demos/dr-car-rides` demonstration with a clear multi-target structure:
- **`ccloud/`**: Confluent Cloud DR deployment (IaC supporting primary and secondary sites, Flink SQL, Tableflow, and failover/failback scripts).
- **`python/`**: Platform-agnostic producer, consumer, and loss assessment tooling (reusable across Confluent Cloud, Confluent Platform, and Apache Kafka/Flink).
- **Future targets** (`cp-flink/` for Confluent Platform and `oss/` for Apache Kafka + Apache Flink) defined as roadmap items in the architecture.
- **`AGENTS.md`**: Dedicated guidance file for AI agents interacting with `e2e-demos/dr-car-rides`, establishing context, conventions, folder architecture, and operating practices.

---

## Sub-Tasks

### Sub-Task 1: Create `e2e-demos/dr-car-rides/AGENTS.md`
- **Intent**: Provide agent-specific context and instructions for the `dr-car-rides` demo, establishing clear boundaries between `ccloud/`, `python/`, and future `cp/` / `oss/` targets, as well as IaC and script execution rules.
- **Expected Outcomes**:
  - `e2e-demos/dr-car-rides/AGENTS.md` created describing the demo purpose, directory layout, environment variables, tooling practices, and DR concepts (Cluster Linking, Schema Linking in IMPORT mode, soft vs promote failover, failback).
- **Todo List**:
  - [ ] Author `e2e-demos/dr-car-rides/AGENTS.md` with demo architecture, component responsibilities, and guidelines.
- **Relevant Context**:
  - `AGENTS.md` (root agent file)
  - `e2e-demos/dr-car-rides/README.md`
- **Status**: `[x] completed`

---

### Sub-Task 2: Fix and Align Operational Shell Scripts
- **Intent**: Ensure `failover-soft.sh`, `failover-promote.sh`, and `failback.sh` accurately orchestrate failover and failback using the real tools in `ccloud/flink-sql/` (Makefile and `deploy_manifest.json` statement names).
- **Expected Outcomes**:
  - `failover-soft.sh` stops primary statements using correct names from `deploy_manifest.json` (`flink-sql-dims-pipeline-rides-clean`, `flink-sql-facts-pipeline-driver-stats`), sets up DR Schema Registry (`READWRITE`), and executes DR Flink deployment via `make -C "$SCRIPT_DIR/../flink-sql" deploy SITE=dr`.
  - `failover-promote.sh` promotes mirror topics on DR cluster via `confluent kafka mirror promote/failover`, handles errors cleanly, and calls the updated soft-failover deploy step.
  - `failback.sh` contains complete and accurate step-by-step commands/instructions for reversing Schema Linking, catching up primary, redeploying primary Flink, and restoring steady state.
- **Todo List**:
  - [ ] Update `failover-soft.sh` to remove phantom `FLINK_TF`/`DR_STATE` references and use `make -C "$SCRIPT_DIR/../flink-sql" deploy SITE=dr` and match statement names from `deploy_manifest.json`.
  - [ ] Validate `failover-promote.sh` logic with appropriate link and topic variables.
  - [ ] Update `failback.sh` with actionable steps and commands matching the repository setup.
- **Relevant Context**:
  - `e2e-demos/dr-car-rides/ccloud/scripts/failover-soft.sh`
  - `e2e-demos/dr-car-rides/ccloud/scripts/failover-promote.sh`
  - `e2e-demos/dr-car-rides/ccloud/scripts/failback.sh`
  - `e2e-demos/dr-car-rides/ccloud/flink-sql/deploy_manifest.json`
  - `e2e-demos/dr-car-rides/ccloud/flink-sql/Makefile`
- **Status**: `[x] completed`

---

### Sub-Task 3: Enhance Loss Assessment Tool with SR Wire Format Support
- **Intent**: Ensure `assess_loss.py` is platform-agnostic and able to directly sample and decode Confluent Schema Registry JSON wire format records (5-byte header: `0x00` magic byte + 4-byte schema ID followed by JSON payload) from Kafka topics.
- **Expected Outcomes**:
  - `assess_loss.py` `--sample-topic` succeeds on `rides_raw` / `rides_clean` / `driver_stats` when messages use Schema Registry JSON wire format or plain JSON.
  - RPO loss estimation accurately compares producer log high-water seq and sampled Kafka/mirror topic seq.
- **Todo List**:
  - [ ] Update `_sample_topic_max_seq` in `assess_loss.py` to parse both raw JSON and Confluent Schema Registry wire-format JSON (skipping 5-byte header).
  - [ ] Add verification/dry-run test to ensure robust JSON parsing.
- **Relevant Context**:
  - `e2e-demos/dr-car-rides/python/assess_loss.py`
  - `e2e-demos/dr-car-rides/python/produce_rides.py`
- **Status**: `[x] completed`

---

### Sub-Task 4: Clarify and Fix Tableflow, IaC, and Flink SQL Metadata
- **Intent**: Clarify how IaC in `ccloud/IaC/` provisions primary and DR infrastructure, how Tableflow is configured, and ensure all SQL comment references point to valid documents.
- **Expected Outcomes**:
  - `dims/dml.rides_clean.sql` comment removed or pointed to the main DR README instead of missing `DESIGN.md`.
  - `ccloud/flink-sql/dr/README.md` updated to remove phantom `terraform/README.md` reference and describe failover deployment using `make deploy SITE=dr`.
  - `ccloud/IaC/README.md` completed with clear instructions for provisioning primary and secondary/DR sites.
- **Todo List**:
  - [ ] Fix comment in `e2e-demos/dr-car-rides/ccloud/flink-sql/dims/dml.rides_clean.sql`.
  - [ ] Update `e2e-demos/dr-car-rides/ccloud/flink-sql/dr/README.md`.
  - [ ] Update `e2e-demos/dr-car-rides/ccloud/IaC/README.md` to complete missing steps for provisioning primary and DR environments.
- **Relevant Context**:
  - `e2e-demos/dr-car-rides/ccloud/flink-sql/dims/dml.rides_clean.sql`
  - `e2e-demos/dr-car-rides/ccloud/flink-sql/dr/README.md`
  - `e2e-demos/dr-car-rides/ccloud/IaC/README.md`
  - `e2e-demos/dr-car-rides/ccloud/IaC/aws.tf`
- **Status**: `[x] completed`

---

### Sub-Task 5: Comprehensive README Alignment and Documentation Polish
- **Intent**: Ensure top-level and ccloud-specific documentation provides an accurate, cohesive guide with clean terminology (active/passive Kafka + Schema Registry + optional standby Flink SQL), explicit architectural roadmap for CP and OSS, and working commands.
- **Expected Outcomes**:
  - `e2e-demos/dr-car-rides/README.md` clearly explains the DR architecture, marks `ccloud/` as ready, and describes the planned `cp/` and `oss/` targets.
  - `e2e-demos/dr-car-rides/ccloud/README.md` fixes directory typos (`cccloud`), fills out phase tables, and documents the exact deployment & failover workflow.
- **Todo List**:
  - [ ] Update `e2e-demos/dr-car-rides/README.md` to streamline the architectural narrative, structure the targets, and fix outdated references.
  - [ ] Update `e2e-demos/dr-car-rides/ccloud/README.md` to correct directory paths, complete phase tables, and align runbook steps.
- **Relevant Context**:
  - `e2e-demos/dr-car-rides/README.md`
  - `e2e-demos/dr-car-rides/ccloud/README.md`
  - `docs/cookbook/cluster_mgt.md`
- **Status**: `[x] completed`

---

### Sub-Task 6: Repository Hygiene & Artifact Cleanup
- **Intent**: Ensure sensitive state files, outputs, virtual environment folders, and compiler caches are cleaned up and excluded by `.gitignore`.
- **Expected Outcomes**:
  - Unneeded temporary files or tracked artifacts are safely ignored and clean.
- **Todo List**:
  - [ ] Verify `.gitignore` rules in `e2e-demos/dr-car-rides/` and subdirectories (`IaC`, `python`, `scripts`).
- **Relevant Context**:
  - `e2e-demos/dr-car-rides/ccloud/IaC/.gitignore`
  - `e2e-demos/dr-car-rides/ccloud/scripts/.gitignore`
- **Status**: `[x] completed`
