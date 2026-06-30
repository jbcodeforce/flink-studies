# Deploy manifest conventions

Each `cccloud/` folder should include `deploy_manifest.json` for [code/flink-sql/tools/cc_deploy](../../../code/flink-sql/tools/cc_deploy/).

## Generate manifest

```bash
cd assistants/jump_start_demo/tools && uv sync
uv run jump-start manifest --path ../../../e2e-demos/<demo>/cccloud
```

Or from flink-sql tools directly:

```bash
cd code/flink-sql/tools
uv run python -m cc_deploy.create_deploy_manifest --sql-dir ../../e2e-demos/<demo>/cccloud
```

## Manifest structure

```json
{
  "user_agent": "flink-studies-<demo>/0.1",
  "deploy_all": ["ddl", "pipeline", "data"],
  "undeploy_all": ["scenario", "data", "pipeline"],
  "drop_tables": ["sink_table", "source_table"],
  "groups": {
    "ddl": [{"name": "<demo>-ddl-entity", "file": "ddl.entity.sql"}],
    "pipeline": [{"name": "<demo>-pipeline", "file": "dml.pipeline.sql"}]
  }
}
```

## Deploy commands

From `cccloud/` (Makefile delegates to shared tools):

```bash
make sync
make deploy-ddl
make deploy-pipeline
make undeploy
make drop-tables
```

## Credentials

Set in `~/.confluent/.env`:

| Variable | Purpose |
|----------|---------|
| `FLINK_API_KEY`, `FLINK_API_SECRET` | Flink REST API |
| `ORGANIZATION_ID`, `ENVIRONMENT_ID` | Target org/env |
| `COMPUTE_POOL_ID`, `DB_NAME` | Compute pool and Kafka cluster |

See [code/flink-sql/tools/README.md](../../../code/flink-sql/tools/README.md) for full list.
