#!/usr/bin/env python3
"""Fetch Confluent Schema Registry subjects for a Kafka topic and emit dbt YAML.

Reads the key and/or value schema registered under ``{topic}-key`` /
``{topic}-value`` and prints a ready-to-paste dbt YAML block to stdout.

Two output modes are supported:

- ``--output sources`` (default) — emits a ``sources:`` block for
  ``models/sources.yaml`` (``contract.enforced: true``).
- ``--output model``   — emits a ``models:`` block for a staging-model YAML
  file (``contract.enforced: false``).

Schema Registry credentials are resolved in priority order:
  1. CLI flags (``--sr-url``, ``--sr-key``, ``--sr-secret``)
  2. Environment variables (``SCHEMA_REGISTRY_URL`` / ``SCHEMA_REGISTRY_ENDPOINT``,
     ``SCHEMA_REGISTRY_API_KEY`` / ``SCHEMA_REGISTRY_USER``,
     ``SCHEMA_REGISTRY_API_SECRET`` / ``SCHEMA_REGISTRY_PASSWORD``)

Examples::

    # Value schema, sources block (defaults)
    uv run sr_to_dbt_yaml.py raw_hosts

    # Both key and value schemas
    uv run sr_to_dbt_yaml.py raw_hosts --subject-suffix key,value

    # Model YAML block for the src_hosts staging model
    uv run sr_to_dbt_yaml.py raw_hosts --output model --schema-name src_hosts

    # Explicit credentials
    uv run sr_to_dbt_yaml.py raw_hosts \\
        --sr-url https://psrc-xxx.us-east-2.aws.confluent.cloud \\
        --sr-key ABCDEF \\
        --sr-secret mysecret
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path


# ---------------------------------------------------------------------------
# cm_py_lib discovery (same pattern as produce_to_kafka.py)
# ---------------------------------------------------------------------------

def _cm_py_lib_root() -> Path:
    """Walk parent directories to locate code/flink-sql/cm_py_lib."""
    marker = Path("code") / "flink-sql" / "cm_py_lib" / "schema_registry.py"
    for parent in Path(__file__).resolve().parents:
        candidate = parent / marker
        if candidate.is_file():
            return parent / "code" / "flink-sql"
    raise RuntimeError(
        "Could not find code/flink-sql/cm_py_lib/schema_registry.py. "
        "Run inside the flink-studies repo."
    )


def _setup_cm_py_lib() -> None:
    root = _cm_py_lib_root()
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))


# ---------------------------------------------------------------------------
# Env-var helpers
# ---------------------------------------------------------------------------

def _env_first(*names: str) -> str:
    """Return the value of the first set (non-empty) env var, or ''."""
    for name in names:
        value = os.environ.get(name, "")
        if value:
            return value
    return ""


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Fetch SR schemas for a Kafka topic and emit dbt YAML.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "topic",
        help="Kafka topic name (e.g. raw_hosts).",
    )
    parser.add_argument(
        "--subject-suffix",
        default="value",
        metavar="SUFFIX",
        help=(
            "Comma-separated subject suffixes to fetch: 'key', 'value', or "
            "'key,value' (default: value)."
        ),
    )
    parser.add_argument(
        "--output",
        choices=["sources", "model"],
        default="sources",
        help=(
            "'sources' emits a sources: block (contract.enforced: true); "
            "'model' emits a models: block (contract.enforced: false). "
            "Default: sources."
        ),
    )
    parser.add_argument(
        "--schema-name",
        default="",
        metavar="NAME",
        help=(
            "Override the name used in the YAML output. "
            "For --output sources this sets schema: and source name (default: topic). "
            "For --output model this sets the model name (default: topic)."
        ),
    )
    parser.add_argument(
        "--sr-url",
        default="",
        metavar="URL",
        help=(
            "Schema Registry URL "
            "(env: SCHEMA_REGISTRY_URL or SCHEMA_REGISTRY_ENDPOINT)."
        ),
    )
    parser.add_argument(
        "--sr-key",
        default="",
        metavar="KEY",
        help=(
            "Schema Registry API key "
            "(env: SCHEMA_REGISTRY_API_KEY or SCHEMA_REGISTRY_USER)."
        ),
    )
    parser.add_argument(
        "--sr-secret",
        default="",
        metavar="SECRET",
        help=(
            "Schema Registry API secret "
            "(env: SCHEMA_REGISTRY_API_SECRET or SCHEMA_REGISTRY_PASSWORD)."
        ),
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    _setup_cm_py_lib()

    # Import after sys.path is patched.
    from cm_py_lib.schema_registry import (  # noqa: PLC0415
        SchemaFetcher,
        schema_to_columns,
        render_sources_yaml,
        render_model_yaml,
    )
    from confluent_kafka.schema_registry.error import SchemaRegistryError  # noqa: PLC0415

    args = build_arg_parser().parse_args(argv)

    # Resolve credentials: CLI flag > env var.
    sr_url = args.sr_url or _env_first("SCHEMA_REGISTRY_URL", "SCHEMA_REGISTRY_ENDPOINT")
    sr_key = args.sr_key or _env_first("SCHEMA_REGISTRY_API_KEY", "SCHEMA_REGISTRY_USER")
    sr_secret = args.sr_secret or _env_first(
        "SCHEMA_REGISTRY_API_SECRET", "SCHEMA_REGISTRY_PASSWORD"
    )

    if not sr_url:
        print(
            "Error: Schema Registry URL is required. "
            "Set SCHEMA_REGISTRY_URL or use --sr-url.",
            file=sys.stderr,
        )
        return 1

    # Parse subject suffixes.
    suffixes = [s.strip() for s in args.subject_suffix.split(",") if s.strip()]
    invalid = [s for s in suffixes if s not in ("key", "value")]
    if invalid:
        print(
            f"Error: invalid --subject-suffix value(s): {invalid}. "
            "Use 'key', 'value', or 'key,value'.",
            file=sys.stderr,
        )
        return 1

    schema_name = args.schema_name or args.topic

    try:
        fetcher = SchemaFetcher(url=sr_url, key=sr_key, secret=sr_secret)
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    output_blocks: list[str] = []

    for suffix in suffixes:
        subject = f"{args.topic}-{suffix}"
        try:
            schema, schema_type = fetcher.fetch(subject)
        except SchemaRegistryError as exc:
            print(f"Error fetching subject '{subject}': {exc}", file=sys.stderr)
            return 1

        try:
            columns = schema_to_columns(schema, schema_type)
        except NotImplementedError as exc:
            print(f"Error: {exc}", file=sys.stderr)
            return 1
        except ValueError as exc:
            print(f"Error: {exc}", file=sys.stderr)
            return 1

        if len(suffixes) > 1:
            output_blocks.append(f"# --- subject: {subject} ---")

        if args.output == "sources":
            output_blocks.append(render_sources_yaml(args.topic, schema_name, columns))
        else:
            output_blocks.append(render_model_yaml(schema_name, columns))

    print("\n".join(output_blocks), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
