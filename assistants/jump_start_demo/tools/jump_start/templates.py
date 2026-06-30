"""Load and render template files with {{placeholder}} substitution."""

from __future__ import annotations

import re
from pathlib import Path

_PACKAGE_ROOT = Path(__file__).resolve().parents[1]
TEMPLATES_DIR = _PACKAGE_ROOT.parent / "templates"

_PLACEHOLDER = re.compile(r"\{\{(\w+)\}\}")


def render_text(content: str, **values: str) -> str:
    def repl(match: re.Match[str]) -> str:
        key = match.group(1)
        return values.get(key, match.group(0))

    return _PLACEHOLDER.sub(repl, content)


def load_template(relative_path: str) -> str:
    path = TEMPLATES_DIR / relative_path
    if not path.is_file():
        raise FileNotFoundError(f"Template not found: {relative_path}")
    return path.read_text(encoding="utf-8")


def render_template(relative_path: str, **values: str) -> str:
    return render_text(load_template(relative_path), **values)


def list_template_files() -> list[str]:
    if not TEMPLATES_DIR.is_dir():
        return []
    return sorted(
        str(path.relative_to(TEMPLATES_DIR))
        for path in TEMPLATES_DIR.rglob("*.tmpl")
    )
