"""
Cli to manage a Flink dbt project to shift left from a batch processing.
Support the concept of star schema and data product or kimball with data product
"""

import enum
from pathlib import Path
from typing import Annotated

import typer
import yaml
from pydantic import BaseModel

# ---------------------------------------------------------------------------
# dbt pipeline scaffold (mirrors `dbt init -s`)
# ---------------------------------------------------------------------------

_DBT_PROJECT_YML = """\

# Name your project! Project names should contain only lowercase characters
# and underscores. A good package name should reflect your organization's
# name or the intended use of these models
name: '{project_name}'
version: '1.0.0'

# This setting configures which "profile" dbt uses for this project.
profile: '{profile_name}'

# These configurations specify where dbt should look for different types of files.
# The `model-paths` config, for example, states that models in this project can be
# found in the "models/" directory. You probably won't need to change these!
model-paths: ["models"]
test-paths: ["tests"]
seed-paths: ["seeds"]
macro-paths: ["macros"]


clean-targets:         # directories to be removed by `dbt clean`
  - "target"
  - "dbt_packages"


# Configuring models
# Full documentation: https://docs.getdbt.com/docs/configuring-models

models:
  {project_name}:
    # Config indicated by + and applies to all files under models/example/
    example:
      +materialized: view
"""

_GITIGNORE = """\

target/
dbt_packages/
logs/
"""

class ProjectType(str, enum.Enum):
    data_product = "data-product"
    kimball = "kimball"

def _write(path: Path, content: str) -> None:
    """Write *content* to *path*, creating parent directories as needed."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def create_pipelines_hierarchy(pipelines_dir: Path, type: ProjectType, profile_name: str) -> None:
    """Create the standard dbt project structure under *pipelines_dir*.

    Produces the same layout as ``dbt init -s`` (skip profile setup):

        pipelines/
        ├── .gitignore
        ├── dbt_project.yml
        ├── macros/            (empty, tracked via .gitkeep)
        ├── models/
        ├── seeds/             (empty, tracked via .gitkeep)
        └── tests/             (empty, tracked via .gitkeep)
    """
    project_name = pipelines_dir.name  # folder name is the dbt project name

    # Top-level files
    _write(pipelines_dir / ".gitignore", _GITIGNORE)
    _write(
        pipelines_dir / "dbt_project.yml",
        _DBT_PROJECT_YML.format(project_name=project_name, profile_name=profile_name),
    )

    # Empty directories tracked by .gitkeep
    for empty_dir in ( "macros", "seeds",  "tests"):
        _write(pipelines_dir / empty_dir / ".gitkeep", "")
    models_path = pipelines_dir / "models"
    models_path.parent.mkdir( exist_ok=True)
    if type == ProjectType.kimball:
        for kb_dir in ["sources", "intermediates", "marts"]:
            _write(pipelines_dir / "models" / kb_dir / ".gitkeep", "")

# ---------------------------------------------------------------------------
# Project metadata  (sl_dbt.yaml)
# ---------------------------------------------------------------------------

_METADATA_FILE = "sl_dbt.yaml"

class ProjectMetadata(BaseModel):
    """Persisted project settings written to sl_dbt.yaml."""

    pipelines_dir: str        # name of the folder holding dbt SQL (e.g. "pipelines")
    project_type: ProjectType
    profile_name: str

    def to_yaml(self) -> str:
        """Serialise the model to a YAML string (enum values as plain strings)."""
        return yaml.dump(self.model_dump(mode="json"), sort_keys=False)


def save_metadata(root: Path, meta: ProjectMetadata) -> None:
    """Persist *meta* to <root>/sl_dbt.yaml."""
    _write(root / _METADATA_FILE, meta.to_yaml())


def load_metadata(root: Path) -> ProjectMetadata:
    """Load project metadata from <root>/sl_dbt.yaml.

    Raises ``typer.Exit`` with an error message when the file is absent.
    """
    meta_path = root / _METADATA_FILE
    if not meta_path.exists():
        typer.echo(
            f"No {_METADATA_FILE} found in {root}. Run `init` first.", err=True
        )
        raise typer.Exit(code=1)
    return ProjectMetadata.model_validate(yaml.safe_load(meta_path.read_text()))


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

app = typer.Typer(
    name="sl-dbt",
    help=__doc__,
    no_args_is_help=True,
)


@app.command()
def init(
    project_root: Annotated[Path, typer.Argument(help="Project root folder path (e.g. ./crm_analytics)")],
    type: Annotated[
        ProjectType,
        typer.Option(
            help=(
                "'data-product': folder tree based on data product then star schema. "
                "'kimball': top level represents the medallion levels (sources, intermediates, marts)."
            ),
        ),
    ] = ProjectType.data_product,
    profile: Annotated[str, typer.Option(help="profile name in the .dbt/profiles.yml")] = "cc_flink"
) -> None:
    """Initialise a new shift-left dbt project skeleton."""
    project_root.mkdir(parents=True, exist_ok=True)
    for sub in ("IaC", "docs", "tools"):
        (project_root / sub).mkdir(exist_ok=True)
    pipelines_name = "pipelines"
    create_pipelines_hierarchy(project_root / pipelines_name, type, profile)
    save_metadata(project_root, ProjectMetadata(pipelines_dir=pipelines_name, project_type=type, profile_name=profile))
    typer.echo(f"Project initialised at {project_root.resolve()}")


@app.command()
def add_data_product(
    project_root: Annotated[Path, typer.Argument(help="Existing project root folder path")],
    name: Annotated[str, typer.Argument(help="Data-product name (lowercase, underscores)")],
) -> None:
    """Add a new data-product sub-tree under <project_root>/<pipelines_dir>/models/<name>."""
    meta = load_metadata(project_root)
    if meta.project_type == ProjectType.data_product:
        dp_dir = project_root / meta.pipelines_dir / "models" / name
        dp_dir.mkdir(parents=True, exist_ok =True)
        _write(dp_dir / "schema.yml", f"version: 2\n\nmodels:\n  - name: {name}\n    description: \"\"\n")
        for sub in ["sources", "facts", "dimensions"]:
            _write(dp_dir / sub / ".gitkeep", "")

        typer.echo(f"Data product '{name}' created at {dp_dir.resolve()}")
    else:
        for sub in ["sources", "intermediates", "marts"]:
            dp_dir = project_root / meta.pipelines_dir / "models" / sub / name
            _write(dp_dir / ".gitkeep", "")
            gitkeep = project_root / meta.pipelines_dir / "models" / sub / ".gitkeep"
            try:
                gitkeep.unlink()
            except FileNotFoundError:
                pass
            except PermissionError:
                pass


if __name__ == "__main__":
    app()
