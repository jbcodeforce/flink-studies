# Flink SQL Tools

Update 09/2026, the Python deploy tools (`cc_deploy`, `manifest`, `kafka`) have moved to the
[flink-tools-for-agents](https://github.com/jbcodeforce/flink-tools-for-agents) repository.

This directory now contains only:

| File | Purpose |
|------|---------|
| `Makefile` | Backward-compatible shim — forwards all targets to `tools.mk` at the repo root |
| `cp_flink_rest_client.py` | Confluent Platform / CMF (on-prem) REST client — stays here |
| `cp_flink_utils.py` | Kubernetes pod-check helper for CMF — stays here |
| `gen_flink_wide_table.py` | One-off generator for wide test tables — stays here |
| `flink_wide_table.sql` | Generated wide-table DDL — stays here |
| tests | for testing cm_py_lib and tools in this folder | 

## How demos still work

All existing Makefiles that do `$(MAKE) -C $(TOOLS) deploy SQL_DIR=...` continue to work unchanged — they point at this directory's `Makefile`, which forwards to the root `tools.mk`.

## Install the tools

```bash
# From the flink-studies repo root:
make -f tools.mk sync

# Or from any demo directory that includes the shim:
make sync
```

## Where the tools live now

```
../flink-tools-for-agents/      ← sibling of flink-studies
  tools/flink/cc_deploy/        ← deploy/undeploy/snapshot/stream
  tools/flink/manifest/         ← manifest generation
  tools/kafka/                  ← Schema Registry + table cleanup
  tools/dbt/                    ← dbt migration + scaffolding
  skills/                       ← Bob/Claude agent skills
```


## Run tests

* under tools folder:
  ```sh
  source .venv/bin/activate
  ```
* Set environment variables in .env and reference the file
  ```set
  set DEMO_ENV_FILE=.../.env
  ```
  
* Validate The common modules for Kafka producers and schema registry
  ```sh
  uv run pytest -vs tests/test_cm_py_lib.py 
  ```