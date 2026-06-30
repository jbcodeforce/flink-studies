#!/usr/bin/env python3
"""CLI for jump-start demo scaffolding."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from jump_start.manifest import generate_manifest_json
from jump_start.scaffold import DemoSpec, scaffold_demo
from jump_start.templates import list_template_files
from jump_start.validate import validate_demo


def _cmd_init(args: argparse.Namespace) -> int:
    targets = [t.strip() for t in args.targets.split(",") if t.strip()]
    topics = [t.strip() for t in args.topics.split(",") if t.strip()]
    spec = DemoSpec(
        name=args.name,
        domain=args.domain,
        targets=targets,
        topics=topics,
        entities=[e.strip() for e in args.entities.split(",") if e.strip()] if args.entities else [],
        description=args.description or "",
        output_dir=Path(args.output) if args.output else None,
    )
    try:
        demo_dir = scaffold_demo(spec, overwrite=args.overwrite)
    except (FileExistsError, ValueError) as exc:
        print(exc, file=sys.stderr)
        return 1

    print(f"Created demo at {demo_dir}")

    if "cccloud" in targets and args.manifest:
        cc_dir = demo_dir / "cccloud"
        try:
            payload = generate_manifest_json(cc_dir, prefix=spec.name, overwrite=True)
            print(f"Generated {cc_dir / 'deploy_manifest.json'}")
            if args.verbose:
                print(payload)
        except Exception as exc:
            print(f"Warning: manifest generation failed: {exc}", file=sys.stderr)

    return 0


def _cmd_validate(args: argparse.Namespace) -> int:
    result = validate_demo(Path(args.path))
    print(result.summary())
    return 0 if result.ok else 1


def _cmd_manifest(args: argparse.Namespace) -> int:
    sql_dir = Path(args.path)
    try:
        text = generate_manifest_json(
            sql_dir,
            prefix=args.prefix,
            overwrite=args.overwrite,
            dry_run=args.dry_run,
        )
    except Exception as exc:
        print(exc, file=sys.stderr)
        return 1
    print(text)
    if args.dry_run:
        print(f"\n(dry-run: not written to {sql_dir / 'deploy_manifest.json'})", file=sys.stderr)
    return 0


def _cmd_list_templates(_args: argparse.Namespace) -> int:
    for rel in list_template_files():
        print(rel)
    return 0


def _cmd_list_use_cases(_args: argparse.Namespace) -> int:
    ref = Path(__file__).resolve().parents[1].parent / "reference" / "use-case-templates.md"
    if ref.is_file():
        print(ref.read_text(encoding="utf-8"))
    else:
        print("use-case-templates.md not found", file=sys.stderr)
        return 1
    return 0


def main() -> None:
    parser = argparse.ArgumentParser(description="Scaffold Flink e2e demo foundations")
    sub = parser.add_subparsers(dest="command", required=True)

    init_p = sub.add_parser("init", help="Create a new demo scaffold")
    init_p.add_argument("--name", required=True, help="Demo slug (e.g. order-tracking)")
    init_p.add_argument("--domain", required=True, help="Business domain (e.g. retail)")
    init_p.add_argument(
        "--targets",
        default="cccloud,oss-flink",
        help="Comma-separated: cccloud, oss-flink, cp-flink",
    )
    init_p.add_argument("--topics", required=True, help="Comma-separated Kafka topic names")
    init_p.add_argument("--entities", default="", help="Optional comma-separated table entity names")
    init_p.add_argument("--description", default="", help="Demo description")
    init_p.add_argument("--output", default="", help="Output directory (default: e2e-demos/<name>)")
    init_p.add_argument("--overwrite", action="store_true", help="Replace existing demo directory")
    init_p.add_argument("--no-manifest", dest="manifest", action="store_false", help="Skip manifest generation")
    init_p.add_argument("--verbose", action="store_true")
    init_p.set_defaults(manifest=True)
    init_p.set_defaults(func=_cmd_init)

    val_p = sub.add_parser("validate", help="Validate demo structure")
    val_p.add_argument("--path", required=True, help="Path to demo root")
    val_p.set_defaults(func=_cmd_validate)

    man_p = sub.add_parser("manifest", help="Generate deploy_manifest.json for cccloud folder")
    man_p.add_argument("--path", required=True, help="Path to cccloud SQL folder")
    man_p.add_argument("--prefix", default=None, help="Statement name prefix")
    man_p.add_argument("--overwrite", action="store_true", default=True)
    man_p.add_argument("--dry-run", action="store_true")
    man_p.set_defaults(func=_cmd_manifest)

    sub.add_parser("list-templates", help="List available templates").set_defaults(
        func=_cmd_list_templates
    )
    sub.add_parser("list-use-cases", help="Print use-case template reference").set_defaults(
        func=_cmd_list_use_cases
    )

    args = parser.parse_args()
    sys.exit(args.func(args))


if __name__ == "__main__":
    main()
