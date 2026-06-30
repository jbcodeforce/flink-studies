"""Wrap cc_deploy manifest generation via flink-sql tools."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[4]
CC_TOOLS = REPO_ROOT / "code" / "flink-sql" / "tools"


def generate_manifest(
    sql_dir: Path,
    *,
    prefix: str | None = None,
    overwrite: bool = True,
    dry_run: bool = False,
) -> dict:
    """Generate deploy_manifest.json for a cccloud SQL folder."""
    sql_dir = sql_dir.resolve()
    if not sql_dir.is_dir():
        raise NotADirectoryError(f"SQL directory not found: {sql_dir}")
    if not CC_TOOLS.is_dir():
        raise FileNotFoundError(
            f"flink-sql tools not found: {CC_TOOLS}. "
            "Run: cd code/flink-sql/tools && uv sync"
        )

    cmd = [
        "uv",
        "run",
        "python",
        "-m",
        "cc_deploy.create_deploy_manifest",
        "--sql-dir",
        str(sql_dir),
    ]
    if prefix:
        cmd.extend(["--prefix", prefix])
    if overwrite or dry_run:
        cmd.append("--overwrite")
    if dry_run:
        cmd.append("--dry-run")

    result = subprocess.run(
        cmd,
        cwd=CC_TOOLS,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"manifest generation failed:\n{result.stderr or result.stdout}"
        )

    return json.loads(result.stdout)


def generate_manifest_json(
    sql_dir: Path,
    *,
    prefix: str | None = None,
    overwrite: bool = True,
    dry_run: bool = False,
) -> str:
    payload = generate_manifest(
        sql_dir, prefix=prefix, overwrite=overwrite, dry_run=dry_run
    )
    return json.dumps(payload, indent=2)
