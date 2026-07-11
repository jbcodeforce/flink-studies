"""Run dbt compile and read compiled model SQL for migration validation."""

from __future__ import annotations

import json
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path

import yaml


class DbtCompileError(RuntimeError):
    """Raised when dbt compile fails."""


@dataclass(frozen=True)
class DbtCompileResult:
    project_dir: Path
    model_name: str
    compiled_path: Path
    compiled_sql: str
    stdout: str
    stderr: str


def find_dbt_project(start: Path) -> Path:
    resolved = start.resolve()
    for candidate in [resolved, *resolved.parents]:
        if (candidate / "dbt_project.yml").is_file():
            return candidate
    raise FileNotFoundError(
        f"No dbt_project.yml found walking up from {start}. "
        "Pass --dbt-project-dir explicitly."
    )


def load_project_name(project_dir: Path) -> str:
    data = yaml.safe_load((project_dir / "dbt_project.yml").read_text(encoding="utf-8"))
    name = data.get("name")
    if not name:
        raise ValueError(f"dbt_project.yml in {project_dir} has no 'name' field")
    return str(name)


def relative_model_path(project_dir: Path, model_path: Path) -> Path:
    models_dir = (project_dir / "models").resolve()
    resolved_model = model_path.resolve()
    try:
        return resolved_model.relative_to(models_dir)
    except ValueError as exc:
        raise ValueError(
            f"Model path {model_path} is not under {models_dir}"
        ) from exc


def compiled_model_path(project_dir: Path, relative_path: Path) -> Path:
    project_name = load_project_name(project_dir)
    return project_dir / "target" / "compiled" / project_name / relative_path


def run_dbt_compile(
    project_dir: Path,
    model_name: str,
    *,
    profiles_dir: Path | None = None,
    target: str = "dev",
) -> subprocess.CompletedProcess[str]:
    command = [
        "dbt",
        "compile",
        "--select",
        model_name,
        "--project-dir",
        str(project_dir),
        "--target",
        target,
    ]
    if profiles_dir is not None:
        command.extend(["--profiles-dir", str(profiles_dir)])

    return subprocess.run(
        command,
        capture_output=True,
        text=True,
        check=False,
    )


def read_compiled_sql(compiled_path: Path) -> str:
    if not compiled_path.is_file():
        raise FileNotFoundError(f"Compiled model not found: {compiled_path}")
    return compiled_path.read_text(encoding="utf-8")


def _relation_alias_keys(relation_name: str) -> list[str]:
    keys = [relation_name.strip("`")]
    parts = re.findall(r"`([^`]+)`", relation_name)
    if parts:
        keys.append(".".join(parts))
        keys.append(parts[-1])
    return list(dict.fromkeys(keys))


def resolve_ref_aliases(
    project_dir: Path,
    model_name: str,
    ref_overrides: dict[str, str] | None = None,
) -> dict[str, str]:
    """Map compiled relation names back to original source table names."""
    ref_overrides = ref_overrides or {}
    inverse_overrides = {model: table for table, model in ref_overrides.items()}

    manifest_path = project_dir / "target" / "manifest.json"
    if not manifest_path.is_file():
        return inverse_overrides

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    nodes = manifest.get("nodes", {})
    sources = manifest.get("sources", {})

    model_node = None
    for node in nodes.values():
        if node.get("name") == model_name and node.get("resource_type") == "model":
            model_node = node
            break

    if model_node is None:
        return inverse_overrides

    aliases = dict(inverse_overrides)
    for dep_id in model_node.get("depends_on", {}).get("nodes", []):
        dep = nodes.get(dep_id) or sources.get(dep_id)
        if not dep:
            continue
        dep_name = dep.get("name")
        if not dep_name:
            continue

        resource_type = dep.get("resource_type")
        if resource_type == "source":
            identifier = dep.get("identifier") or dep_name
            clean_identifier = str(identifier).strip("`")
            aliases[dep_name] = dep_name
            aliases[clean_identifier] = dep_name
            for key in _relation_alias_keys(str(identifier)):
                aliases[key] = dep_name
            continue

        relation_name = dep.get("relation_name") or dep.get("alias") or dep_name
        source_name = inverse_overrides.get(dep_name, dep_name)
        if relation_name:
            for key in _relation_alias_keys(str(relation_name)):
                aliases[key] = source_name
        aliases[dep_name] = source_name

    return aliases


def validate_compiled_migration(
    project_dir: Path,
    model_path: Path,
    model_name: str,
    *,
    profiles_dir: Path | None = None,
    target: str = "dev",
    ref_overrides: dict[str, str] | None = None,
) -> DbtCompileResult:
    completed = run_dbt_compile(
        project_dir,
        model_name,
        profiles_dir=profiles_dir,
        target=target,
    )
    if completed.returncode != 0:
        message = completed.stderr.strip() or completed.stdout.strip()
        raise DbtCompileError(message or "dbt compile failed")

    rel_path = relative_model_path(project_dir, model_path)
    compiled_path = compiled_model_path(project_dir, rel_path)
    compiled_sql = read_compiled_sql(compiled_path)

    return DbtCompileResult(
        project_dir=project_dir,
        model_name=model_name,
        compiled_path=compiled_path,
        compiled_sql=compiled_sql,
        stdout=completed.stdout,
        stderr=completed.stderr,
    )
