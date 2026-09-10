

import pytest
from pathlib import Path
from typer.testing import CliRunner

from flink_dbt_migrate.migrate_dml_to_dbt import app

dbt_mig_path =  Path(__file__).resolve().parent
sl_test_pipeline_path = dbt_mig_path.parents[4] / "shift_left_utils" / "src" / "shift_left" / "tests" / "data" / "flink-project" / "pipelines"



@pytest.fixture
def cli_runner() -> CliRunner:
    return CliRunner()


def test_cli_sl_repo_to_dbt(cli_runner: CliRunner, tmp_path: Path):
    print(tmp_path)
    result = cli_runner.invoke(
        app,
        ["migrate-sl-folder", str(sl_test_pipeline_path), str(tmp_path), "--write"],
        catch_exceptions=False, 
    )
    print(result.stdout)
    assert result.exit_code == 0, f"CLI invocation failed (exit_code={result.exit_code}):\n{result.output}"
    