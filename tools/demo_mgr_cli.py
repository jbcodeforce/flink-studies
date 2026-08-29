"""
A e2e demo or code studies creator. This is to be used to template 

"""
from pathlib import Path
import typer
import enum
from typing import Annotated




def _write(path: Path, content: str) -> None:
    """Write *content* to *path*, creating parent directories as needed."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)

class ProjectType(str, enum.Enum):
    e2edemo = "e2e"
    study = "study"

class PlatformType(str, enum.Enum):
    ccf = "cc-flink"
    oss = "oss"
    cpf = "cp-flink"
    all = "all"

app = typer.Typer(
    name="fla",
    help=__doc__,
    no_args_is_help=True,
)

@app.command()
def init(
    project_root: Annotated[Path, typer.Argument(help="Project root folder path (e.g. ./03-nested-row")],
    project_type: Annotated[
        ProjectType,
        typer.Option(
            help=(
                "'e2e': Folder tree for e2e demo, which include IaC. "
                "'study': t."
            ),
        ),
    ] = ProjectType.study,
    platform : Annotated[
        PlatformType,
        typer.Option(
            help=(
                "'cc-flink': project for cc-flink "
                "'cp-flink': project for cp-flink "
                "'oss': project for Apache flink "
                "'all': project for all flavor of flink."
            ),
        ),
    ] = PlatformType.all,
) -> None:
    """
    Initialize one of the possible project/demo 
    """
    project_root.mkdir(parents=True, exist_ok=True)

    match platform:
        case PlatformType.all:
            _write(project_root / "oss" / ".gitkeep", "")
            _write(project_root / "cc-flink" / ".gitkeep", "")
            _write(project_root / "cp-flink" / ".gitkeep", "")
        case PlatformType.oss:
            _write(project_root / "oss" / ".gitkeep", "")
        case PlatformType.cc_flink:
            _write(project_root / "cc-flink" / ".gitkeep", "")
        case PlatformType.cp_flink:
            _write(project_root / "cp-flink" / ".gitkeep", "")
    if project_type == ProjectType.e2edemo:
        _write(project_root / "IaC" / ".gitkeep", "")
    _write(project_root / "docs" / ".gitkeep", "")
    _write(project_root / "README.md", "# ")

    typer.echo(f"Project initialized at {project_root.resolve()} of type: {project_type} on {platform} platform")

if __name__ == "__main__":
    app()