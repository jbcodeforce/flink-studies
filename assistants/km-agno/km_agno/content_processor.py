from pathlib import Path


def list_md_filenames(folder: Path) -> list[str]:
    """
    Walk ``folder`` recursively and return each ``.md`` file's basename.

    Order is sorted by basename for stable output.
    """
    root = (folder / "docs").resolve()
    l = root.rglob("*.md")
    return sorted([p for p in l if p.is_file()])


def get_candidate_files(folder: Path) -> list[str]:
    """
    Back-compat alias for :func:`list_md_filenames`.
    """
    l=list_md_filenames(folder)
    return l
