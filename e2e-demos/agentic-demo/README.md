# Flink Agent demos

End-to-end examples for **agentic streaming** with Apache Flink: local Python Agents (OSS) and Confluent Cloud SQL (“ML first, agent second”). Pairs with the [agentic Flink architecture chapter](../../docs/architecture/agentic_flink.md).

## Business goal

Compare two agentic patterns on streaming data:

1. **OSS — Flink Agents (Python):** workflow vs ReAct quickstarts on a local Flink cluster.
2. **Confluent Cloud — SQL + ML:** reefer cold-chain anomaly detection and gating before LLM/agent escalation.

## Deployment targets

| Target | Path | Status |
|--------|------|--------|
| oss-flink | [`oss-flink/`](oss-flink/) | Local Flink + PyFlink Agents (`flink-agents`, Ollama for ReAct) |
| cccloud | — | Not in this folder; see [`code/flink-sql/12-ai-agents`](../../code/flink-sql/12-ai-agents/) |
| cp-flink | — | Not done yet |

## Quick start

- **Local Flink Agents:** [oss-flink/README.md](oss-flink/README.md) — install, `uv sync`, scripts under `oss-flink/scripts/`.
- **Confluent Cloud SQL lab:** [code/flink-sql/12-ai-agents/README.md](../../code/flink-sql/12-ai-agents/README.md) — Faker source, `ML_DETECT_ANOMALIES`, anomaly escalation view.

## OSS path (summary)

Full runbook: [oss-flink/README.md](oss-flink/README.md).

```sh
cd e2e-demos/agentic-demo
uv venv -p 3.11 && source .venv/bin/activate && uv sync
source oss-flink/scripts/export_pythonpath.sh
./oss-flink/scripts/run_workflow.sh   # or run_react.sh (needs Ollama)
```

**Flink version:** The install example uses `1.20.3` via [`install-flink-local.sh`](../../deployment/product-tar/install-flink-local.sh). Confirm against the [Flink Agents compatibility matrix](https://nightlies.apache.org/flink/flink-agents-docs-latest/docs/get-started/overview/) for the `flink-agents` version pinned in [`pyproject.toml`](pyproject.toml) / `uv.lock`.

## Confluent Cloud path (summary)

Run in a Flink workspace or compute pool (credentials in `~/.confluent/.env`; deploy tooling in [code/flink-sql/tools](../../code/flink-sql/tools/)):

1. Follow [12-ai-agents/README.md](../../code/flink-sql/12-ai-agents/README.md) — reefer telemetries, burst view, `ML_DETECT_ANOMALIES`, `reefer_anomaly_escalations` gating view.
2. Optional replay exercise: [12-ai-agents/REPLAY.md](../../code/flink-sql/12-ai-agents/REPLAY.md).

This is the SQL counterpart to OSS Agents: detect anomalies in Flink, escalate only flagged windows to an agent/LLM consumer.

## Learning paths

### 15 minutes (OSS install check)

1. Complete [oss-flink Phase 1](oss-flink/README.md#phase-1--environment).
2. Success: `./oss-flink/scripts/validate_env.sh` prints `PASS`.

### 1 hour (compare agent patterns)

1. Run `./oss-flink/scripts/run_workflow.sh` and capture output.
2. Run `./oss-flink/scripts/run_react.sh` with Ollama up; compare tool use vs fixed workflow.
3. Skim [12-ai-agents](../../code/flink-sql/12-ai-agents/) and name when SQL+ML gating beats a Python agent loop.

## Troubleshooting

- **`No module named 'flink_agents'` in TaskManager:** Re-run `source oss-flink/scripts/export_pythonpath.sh` in the same shell as the job submit.
- **Flink / PyFlink version skew:** Align tarball with Flink Agents docs and `uv.lock`.
- **Ollama connection errors:** `ollama serve` and `ollama pull qwen3:8b` before `run_react.sh`.

## Layout

| Path | Purpose |
|------|---------|
| [`pyproject.toml`](pyproject.toml) | `flink-agents` dependency (OSS path) |
| [`oss-flink/`](oss-flink/) | Local deployment README + [`scripts/`](oss-flink/scripts/) |
| [`tests/test_imports.sh`](tests/test_imports.sh) | Import smoke test (no cluster) |
| [`code/flink-sql/12-ai-agents/`](../../code/flink-sql/12-ai-agents/) | Confluent Cloud SQL lab (external to this folder) |

## See also

- [Apache Flink Agents – overview](https://nightlies.apache.org/flink/flink-agents-docs-latest/docs/get-started/overview/)
- [Upstream quickstart examples](https://github.com/apache/flink-agents/tree/main/python/flink_agents/examples/quickstart)
- [Confluent built-in ML / agents](https://docs.confluent.io/cloud/current/ai/overview.html)
