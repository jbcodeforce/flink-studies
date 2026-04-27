# Flink Agent demos (OSS)

End-to-end examples using [Apache Flink Agents](https://nightlies.apache.org/flink/flink-agents-docs-latest/docs/get-started/overview/) with local Apache Flink and Python. This folder is the open-source path that pairs with the [agentic Flink architecture chapter](../../docs/architecture/agentic_flink.md); Confluent-only SQL lives under [code/flink-sql/12-ai-agents](../../code/flink-sql/12-ai-agents/).

## Prerequisites

| Requirement | Notes |
| --- | --- |
| Apache Flink | Local cluster; install via [deployment/product-tar/install-flink-local.sh](../../deployment/product-tar/install-flink-local.sh) (example: `./install-flink-local.sh 1.20.3`). |
| Python | 3.11 (see `requires-python` in [pyproject.toml](pyproject.toml)). |
| uv | For the virtualenv and `flink-agents` install. |
| Ollama (for LLM examples) | Bundled quickstarts use [Ollama](https://ollama.com/) with `qwen3:8b` per upstream example code. Install Ollama and `ollama pull qwen3:8b` before running ReAct/workflow demos. |
| `PYTHONPATH` | The Flink Java process must load the same `flink_agents` (and `pyflink`) site-packages the driver uses. Set as below. |

## 15-minute path (install only)

1. From the repository root, install local Flink (adjust version to match your [Flink Agents](https://nightlies.apache.org/flink/flink-agents-docs-release-0.1/) compatibility matrix):

   ```sh
   cd deployment/product-tar
   ./install-flink-local.sh 1.20.3
   ```

2. From this directory (`e2e-demos/agentic-demo`):

   ```sh
   uv venv -p 3.11
   source .venv/bin/activate
   uv sync
   uv run python --version
   ```

3. Export `PYTHONPATH` to the environment `uv` uses (required so the Flink cluster’s Python worker sees the packages):

   ```sh
   export PYTHONPATH="$(uv run python -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')"
   echo "$PYTHONPATH"
   ```

4. Start your Flink cluster the same way you do for other PyFlink jobs in this repo (for example `start-cluster.sh` from the Flink home used by the install script). The exact command depends on your local layout; see [oss-flink/README.md](oss-flink/README.md) and the main Flink install docs.

Success criteria (install): `uv run python -c "import flink_agents, pyflink; print('ok')"` prints `ok` and `PYTHONPATH` points into `.venv/.../site-packages`.

## Run the bundled quickstarts

Upstream ships examples inside the `flink_agents` package. With the venv active and `PYTHONPATH` set, from `e2e-demos/agentic-demo`:

Workflow-style agent (single custom agent on a file source):

```sh
uv run python -m flink_agents.examples.quickstart.workflow_single_agent_example
```


ReAct agent (tools + Ollama):

```sh
# Ensure Ollama is running and the model is available.
uv run python -m flink_agents.examples.quickstart.react_agent_example
```

Examples read JSON product review lines from the package’s `resources/` directory and print analysis to stdout.

Success criteria (run):

- The Flink job submits without `ModuleNotFoundError: flink_agents` in TaskManager logs.
- The job finishes or streams (depending on `monitor_continuously`) and you see printed records on the client.
- If Ollama is down: the ReAct example fails on model calls—start Ollama and retry. That is expected; the integration point is the same in production (health-check your model endpoint).

## Troubleshooting

- **`No module named 'flink_agents'` in TaskManager:** `PYTHONPATH` is wrong or not exported in the shell that launches the job. Re-run the `export PYTHONPATH=...` line in the same session as `uv run python -m ...`.
- **Flink / PyFlink version skew:** align Flink tarball version with the [Flink Agents documentation](https://nightlies.apache.org/flink/flink-agents-docs-latest/docs/get-started/overview/) for your `flink-agents` version from `uv.lock` / `pyproject.toml`.
- **Ollama connection errors:** check `ollama serve` and that `qwen3:8b` (or the model you configure in a forked copy of the example) is pulled.

## 1-hour path (compare two patterns)

1. Run `workflow_single_agent_example` and capture stdout.
2. Run `react_agent_example` with Ollama up; compare how tool calls differ from the workflow agent’s fixed graph.
3. (Optional) Copy one of the example files into this repo and change the Ollama `model=` string to a model you host—re-run and confirm the same `PYTHONPATH` + cluster process still works.

**Success criteria:** you can name when you would use a ReAct loop (unknown steps, tool choice) vs a workflow agent (fixed analysis stages).

## Layout

- [pyproject.toml](pyproject.toml) – `flink-agents` dependency and Python version.
- [oss-flink/README.md](oss-flink/README.md) – local Flink scope notes.
- [uv.lock](uv.lock) – lockfile for reproducible installs.

## See also

- [Apache Flink Agents – overview](https://nightlies.apache.org/flink/flink-agents-docs-latest/docs/get-started/overview/)
- [Source examples on GitHub](https://github.com/apache/flink-agents/tree/main/python/flink_agents/examples/quickstart)
- [Reefer anomaly + gating (Confluent SQL)](../../code/flink-sql/12-ai-agents/) – “ML first, LLM second” in SQL
