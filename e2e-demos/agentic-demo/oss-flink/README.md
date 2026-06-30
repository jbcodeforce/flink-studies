# Agentic demo – OSS Flink (local)

## Goal

Run upstream [Apache Flink Agents](https://nightlies.apache.org/flink/flink-agents-docs-latest/docs/get-started/overview/) quickstarts (workflow agent and ReAct agent) on a **local** OSS Flink cluster with Python 3.11. Demonstrates `PYTHONPATH` wiring so TaskManagers load the same `flink_agents` / `pyflink` packages as the driver.

## Status

Documented. Requires manual Flink install ([deployment/product-tar/install-flink-local.sh](../../../deployment/product-tar/install-flink-local.sh)), `uv` env at demo root, and **Ollama** for the ReAct example.

## Implementation approach

- **No IaC / Docker** in this folder — intentional for PyFlink Agents (tarball + `PYTHONPATH` vs containerized SQL demos).
- **Flink:** Local cluster from product-tar install; align version with [Flink Agents compatibility](https://nightlies.apache.org/flink/flink-agents-docs-latest/docs/get-started/overview/) and [`pyproject.toml`](../pyproject.toml) / `uv.lock`.
- **Application logic:** Upstream modules `flink_agents.examples.quickstart.workflow_single_agent_example` and `react_agent_example` (no repo-owned job module yet).
- **Automation:** Shell scripts under [`scripts/`](scripts/) wrap env setup and example runs.

## How to run

### Phase 1 — Environment

1. Install local Flink (example; verify version against Flink Agents docs):

   ```sh
   cd deployment/product-tar
   ./install-flink-local.sh 1.20.3
   ```

2. From demo root (`e2e-demos/agentic-demo`):

   ```sh
   uv venv -p 3.11
   source .venv/bin/activate
   uv sync
   source oss-flink/scripts/export_pythonpath.sh
   oss-flink/scripts/validate_env.sh
   ```

3. Start your Flink cluster (`start-cluster.sh` from the Flink home used above).

4. For ReAct only: install [Ollama](https://ollama.com/), run `ollama serve`, and `ollama pull qwen3:8b` (model used by upstream example).

### Phase 2 — Application

From demo root with venv active:

```sh
# Workflow agent (file source, no Ollama)
./oss-flink/scripts/run_workflow.sh

# ReAct agent (tools + Ollama)
./oss-flink/scripts/run_react.sh
```

### Success criteria

- `validate_env.sh` exits 0.
- Job submits without `ModuleNotFoundError: flink_agents` in TaskManager logs.
- Client prints analysis output; ReAct fails predictably if Ollama is down.

### Troubleshooting

See [../README.md](../README.md#troubleshooting).

## See also

- [Demo root README](../README.md) — business context and learning paths
- [Agentic Flink architecture chapter](../../../docs/architecture/agentic_flink.md)
