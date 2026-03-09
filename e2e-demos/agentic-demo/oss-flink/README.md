# Agentic demo – Local Flink

## Goal

Flink Agents (Python): use flink-agents package with local Flink. See root [../README.md](../README.md) and [Flink Agents docs](https://nightlies.apache.org/flink/flink-agents-docs-release-0.1/).

## Status

Ready. Local Flink install; Python 3.11 + uv, PYTHONPATH for JVM.

## Implementation approach

- **No IaC.** Local Flink only; no K8s or cloud.
- **Application logic:** Python/uv env and flink-agents at root.

## How to run

From **demo root**: install local Flink, set PYTHONPATH, run agent commands per root README. See [../README.md](../README.md).
