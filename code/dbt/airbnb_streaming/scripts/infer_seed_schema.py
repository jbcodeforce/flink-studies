#!/usr/bin/env python3
"""Infer Flink column types from seed CSVs and merge into seeds/seeds.yml."""

from __future__ import annotations

import argparse
import csv
import re
import sys
from decimal import Decimal, InvalidOperation
from pathlib import Path

import yaml

SEEDS_DIR_NAME = "seeds"
SEEDS_YML_NAME = "seeds.yml"
INT32_MAX = 2_147_483_647
INT32_MIN = -2_147_483_648

DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
DATETIME_RE = re.compile(
    r"^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(\.\d{1,9})?([+-]\d{2}:?\d{2}|Z)?$"
)


def seed_csv_files(seeds_dir: Path) -> list[Path]:
    return sorted(
        p
        for p in seeds_dir.glob("*.csv")
        if p.is_file() and not p.name.startswith("_")
    )


def read_column_values(csv_path: Path) -> dict[str, list[str]]:
    with csv_path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames is None:
            raise ValueError(f"{csv_path}: missing header row")
        columns = {name: [] for name in reader.fieldnames}
        for row in reader:
            for name in columns:
                value = row.get(name)
                if value is not None and value != "":
                    columns[name].append(value.strip())
        return columns


def infer_flink_type(values: list[str]) -> str:
    if not values:
        return "STRING"

    if all(DATE_RE.match(value) for value in values):
        return "DATE"

    if all(DATETIME_RE.match(value) for value in values):
        return "TIMESTAMP(3)"

    if all(_is_int(value) for value in values):
        nums = [int(value) for value in values]
        if any(n < INT32_MIN or n > INT32_MAX for n in nums):
            return "BIGINT"
        return "INT"

    if all(_is_decimal(value) for value in values):
        return "DECIMAL(18,2)"

    return "STRING"


def _is_int(value: str) -> bool:
    try:
        int(value)
    except ValueError:
        return False
    return True


def _is_decimal(value: str) -> bool:
    try:
        Decimal(value)
    except InvalidOperation:
        return False
    return "." in value


def seed_name_from_csv(csv_path: Path) -> str:
    return csv_path.stem


def default_alias(seed_name: str) -> str:
    if seed_name.startswith("seed_"):
        return f"raw_{seed_name.removeprefix('seed_')}"
    return f"raw_{seed_name}"


def load_seeds_yml(path: Path) -> dict:
    if not path.exists():
        return {"version": 2, "seeds": []}
    with path.open(encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    data.setdefault("version", 2)
    data.setdefault("seeds", [])
    return data


def seed_entry_index(data: dict, seed_name: str) -> int | None:
    for index, entry in enumerate(data["seeds"]):
        if entry.get("name") == seed_name:
            return index
    return None


def merge_inferred_types(
    data: dict,
    seed_name: str,
    column_types: dict[str, str],
) -> dict[str, str]:
    index = seed_entry_index(data, seed_name)
    if index is None:
        data["seeds"].append(
            {
                "name": seed_name,
                "config": {
                    "alias": default_alias(seed_name),
                    "column_types": dict(column_types),
                },
            }
        )
        return dict(column_types)

    entry = data["seeds"][index]
    config = entry.setdefault("config", {})
    config.setdefault("alias", default_alias(seed_name))
    existing = config.setdefault("column_types", {})
    merged = dict(existing)
    for column, flink_type in column_types.items():
        merged.setdefault(column, flink_type)
    config["column_types"] = merged
    return merged


def build_seeds_config(seeds_dir: Path) -> tuple[dict, dict[str, dict[str, str]]]:
    data = load_seeds_yml(seeds_dir / SEEDS_YML_NAME)
    inferred_by_seed: dict[str, dict[str, str]] = {}

    for csv_path in seed_csv_files(seeds_dir):
        seed_name = seed_name_from_csv(csv_path)
        columns = read_column_values(csv_path)
        column_types = {
            column: infer_flink_type(values) for column, values in columns.items()
        }
        merge_inferred_types(data, seed_name, column_types)
        inferred_by_seed[seed_name] = column_types

    data["seeds"] = sorted(data["seeds"], key=lambda entry: entry["name"])
    return data, inferred_by_seed


def dump_seeds_yml(path: Path, data: dict) -> str:
    text = yaml.safe_dump(
        data,
        sort_keys=False,
        default_flow_style=False,
        allow_unicode=True,
    )
    path.write_text(text, encoding="utf-8")
    return text


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--seeds-dir",
        type=Path,
        default=Path(__file__).resolve().parent.parent / SEEDS_DIR_NAME,
        help="Directory containing seed CSV files (default: ../seeds)",
    )
    parser.add_argument(
        "--write",
        action="store_true",
        help="Write merged seeds.yml (default: dry-run print only)",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Exit 1 if seeds.yml would change (for CI)",
    )
    args = parser.parse_args()

    seeds_dir = args.seeds_dir.resolve()
    seeds_yml = seeds_dir / SEEDS_YML_NAME

    if not seeds_dir.is_dir():
        print(f"Seeds directory not found: {seeds_dir}", file=sys.stderr)
        return 1

    csv_files = seed_csv_files(seeds_dir)
    if not csv_files:
        print(f"No CSV seed files found in {seeds_dir}", file=sys.stderr)
        return 1

    data, inferred = build_seeds_config(seeds_dir)
    new_text = yaml.safe_dump(data, sort_keys=False, default_flow_style=False)

    existing_text = (
        seeds_yml.read_text(encoding="utf-8") if seeds_yml.exists() else ""
    )

    if args.check and existing_text != new_text:
        print(f"{seeds_yml} is out of date; run with --write", file=sys.stderr)
        return 1

    if args.write:
        dump_seeds_yml(seeds_yml, data)
        print(f"Updated {seeds_yml}")
    else:
        print(new_text)

    for seed_name, column_types in inferred.items():
        print(f"# {seed_name}: {column_types}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
