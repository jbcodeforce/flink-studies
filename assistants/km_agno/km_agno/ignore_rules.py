"""File discovery: allowlist extensions, deny directories and sensitive files."""

from __future__ import annotations

import os
from pathlib import Path

# Directory name segments that skip the entire subtree
DENY_DIR_NAMES: frozenset[str] = frozenset(
    {
        ".git",
        ".svn",
        ".hg",
        "__pycache__",
        ".pytest_cache",
        ".mypy_cache",
        ".venv",
        "venv",
        "node_modules",
        "target",
        "build",
        "dist",
        ".next",
        ".terraform",
        ".idea",
        ".vscode",
        "htmlcov",
        ".nyc_output",
    }
)

# File names to skip (segment match)
DENY_FILE_NAMES: frozenset[str] = frozenset(
    {
        ".env",
    }
)

# Lock / generated JSON patterns (by name)
def _is_lock_or_generated(name: str) -> bool:
    lower = name.lower()
    if lower in ("package-lock.json", "poetry.lock", "uv.lock", "cargo.lock", "gemfile.lock"):
        return True
    if lower.endswith("-lock.json"):
        return True
    return False


# Maximum file size to index (bytes)
MAX_FILE_BYTES = 2 * 1024 * 1024

ALLOWED_EXTENSIONS: frozenset[str] = frozenset(
    {
        ".md",
        ".mdx",
        ".py",
        ".pyi",
        ".java",
        ".kt",
        ".kts",
        ".sql",
        ".yaml",
        ".yml",
        ".json",
        ".tf",
        ".tfvars",
        ".hcl",
        ".sh",
        ".bash",
        ".zsh",
        ".xml",
        ".properties",
        ".toml",
        ".cfg",
        ".ini",
        ".html",
        ".css",
        ".js",
        ".mjs",
        ".cjs",
        ".ts",
        ".tsx",
        ".jsx",
        ".go",
        ".rs",
        ".rb",
    }
)

NO_EXTENSION_NAMES: frozenset[str] = frozenset(
    {
        "Dockerfile",
        "Makefile",
        "GNUmakefile",
    }
)


def _denied_name(name: str) -> bool:
    lower = name.lower()
    if any(lower.endswith(s) for s in (".pem", ".p12", ".pfx")):
        return True
    if _is_lock_or_generated(name):
        return True
    return False


def should_index_file(file_path: Path, repo_root: Path) -> bool:
    if not file_path.is_file():
        return False
    try:
        rel = file_path.resolve().relative_to(repo_root.resolve())
    except ValueError:
        return False

    for part in rel.parts:
        if part in DENY_DIR_NAMES or part in DENY_FILE_NAMES:
            return False
        if part == ".env" or _denied_name(part):
            return False

    name = file_path.name
    if name in DENY_FILE_NAMES or _denied_name(name):
        return False

    if name in NO_EXTENSION_NAMES:
        try:
            st = file_path.stat()
        except OSError:
            return False
        if st.st_size > MAX_FILE_BYTES:
            return False
        return True

    if not file_path.suffix and name in ("Dockerfile",):
        try:
            st = file_path.stat()
        except OSError:
            return False
        if st.st_size > MAX_FILE_BYTES:
            return False
        return True

    ext = file_path.suffix.lower()
    if ext not in ALLOWED_EXTENSIONS:
        return False
    try:
        st = file_path.stat()
    except OSError:
        return False
    if st.st_size > MAX_FILE_BYTES:
        return False
    return True


def _prune_dirs(dirnames: list[str], _dirpath: Path) -> None:
    dirnames[:] = [
        d
        for d in dirnames
        if d not in DENY_DIR_NAMES
        and d not in DENY_FILE_NAMES
        and not _denied_name(d)
    ]


def discover_files(repo_root: Path) -> list[Path]:
    root = repo_root.resolve()
    out: list[Path] = []
    for dirpath, dirnames, filenames in os.walk(root, topdown=True, followlinks=False):
        p = Path(dirpath)
        _prune_dirs(dirnames, p)
        for fn in filenames:
            fp = p / fn
            if should_index_file(fp, root):
                out.append(fp)
    return sorted(out)
