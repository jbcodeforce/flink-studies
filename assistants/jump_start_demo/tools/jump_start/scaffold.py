"""Create e2e demo directory trees from a DemoSpec."""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

from jump_start.templates import render_template

REPO_ROOT = Path(__file__).resolve().parents[4]
DEFAULT_OUTPUT_PARENT = REPO_ROOT / "e2e-demos"

VALID_TARGETS = frozenset({"cccloud", "oss-flink", "cp-flink"})


@dataclass
class DemoSpec:
    name: str
    domain: str
    targets: list[str]
    topics: list[str]
    entities: list[str] = field(default_factory=list)
    description: str = ""
    output_dir: Path | None = None

    def __post_init__(self) -> None:
        self.name = _slug(self.name)
        if not self.topics:
            raise ValueError("At least one topic is required")
        if not self.targets:
            raise ValueError("At least one deployment target is required")
        unknown = set(self.targets) - VALID_TARGETS
        if unknown:
            raise ValueError(f"Unknown targets: {sorted(unknown)}; valid: {sorted(VALID_TARGETS)}")
        if not self.entities:
            self.entities = [_entity_from_topic(t) for t in self.topics]

    @property
    def demo_dir(self) -> Path:
        if self.output_dir:
            return self.output_dir.resolve()
        return (DEFAULT_OUTPUT_PARENT / self.name).resolve()

    @property
    def primary_topic(self) -> str:
        return self.topics[0]

    @property
    def primary_entity(self) -> str:
        return self.entities[0] if self.entities else _entity_from_topic(self.primary_topic)

    def template_values(self) -> dict[str, str]:
        rows = []
        target_paths = {
            "cccloud": ("cccloud/", "Confluent Cloud Flink SQL"),
            "oss-flink": ("oss-flink/", "Local Docker (Kafka + Flink)"),
            "cp-flink": ("cp-flink/", "Confluent Platform Flink"),
        }
        for t in self.targets:
            path, desc = target_paths.get(t, (f"{t}/", t))
            rows.append(f"| {t} | `{path}` | Scaffold — customize |")
        return {
            "demo_name": self.name,
            "demo_title": self.name.replace("-", " ").title(),
            "domain": self.domain,
            "description": self.description or f"{self.domain} streaming demo: {self.name}",
            "primary_topic": self.primary_topic,
            "primary_entity": self.primary_entity,
            "entity_class": _entity_class_name(self.primary_entity),
            "topics_list": ", ".join(f"`{t}`" for t in self.topics),
            "topics_csv": ", ".join(self.topics),
            "targets_list": ", ".join(self.targets),
            "targets_table": "\n".join(rows),
            "slug_prefix": self.name,
        }


def _slug(value: str) -> str:
    slug = value.strip().lower().replace("_", "-")
    slug = "".join(c if c.isalnum() or c == "-" else "-" for c in slug)
    while "--" in slug:
        slug = slug.replace("--", "-")
    return slug.strip("-") or "demo"


def _entity_from_topic(topic: str) -> str:
    """Derive a table/entity name from a Kafka topic (singular, snake-ish)."""
    base = topic.replace("-", "_").rstrip("s")
    return base if base else "event"


def _entity_class_name(entity: str) -> str:
    """Pydantic model name from entity slug (e.g. fraud_alert -> FraudAlertRecord)."""
    parts = re.split(r"[-_]+", entity)
    return "".join(p.capitalize() for p in parts if p) + "Record"


def _write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def scaffold_demo(spec: DemoSpec, *, overwrite: bool = False) -> Path:
    """Create demo tree at spec.demo_dir. Returns path to demo root."""
    demo_dir = spec.demo_dir
    if demo_dir.exists() and any(demo_dir.iterdir()) and not overwrite:
        raise FileExistsError(f"Demo directory already exists: {demo_dir} (use overwrite=True)")

    values = spec.template_values()
    created: list[str] = []

    # Root README
    root_readme = render_template("demo-root/README.md.tmpl", **values)
    _write(demo_dir / "README.md", root_readme)
    created.append("README.md")

    if "cccloud" in spec.targets:
        _scaffold_cccloud(demo_dir, spec, values)
        created.extend(_cccloud_paths())

    if "oss-flink" in spec.targets:
        _scaffold_oss_flink(demo_dir, spec, values)
        created.extend(_oss_flink_paths())

    if "cp-flink" in spec.targets:
        _scaffold_cp_flink_stub(demo_dir, values)
        created.append("cp-flink/README.md")

    # Shared Python producer (cm_py_lib) at demo root
    py_dir = demo_dir / "python"
    _write(py_dir / "pyproject.toml", render_template("python/pyproject.toml.tmpl", **values))
    _write(py_dir / "requirements.txt", render_template("python/requirements.txt.tmpl", **values))
    _write(py_dir / "producers" / "produce_messages.py", render_template("python/producer.py.tmpl", **values))
    created.append("python/")

    return demo_dir


def _cccloud_paths() -> list[str]:
    return [
        "cccloud/README.md",
        "cccloud/ddl.source.sql",
        "cccloud/dml.pipeline.sql",
        "cccloud/Makefile",
    ]


def _oss_flink_paths() -> list[str]:
    return [
        "oss-flink/README.md",
        "oss-flink/docker-compose.yml",
        "oss-flink/scripts/run_demo.sh",
    ]


def _scaffold_cccloud(demo_dir: Path, spec: DemoSpec, values: dict[str, str]) -> None:
    cc = demo_dir / "cccloud"
    entity = spec.primary_entity
    cc_values = {**values, "entity": entity, "table_name": entity}

    _write(cc / "README.md", render_template("cccloud/README.md.tmpl", **cc_values))
    _write(cc / f"ddl.{entity}.sql", render_template("cccloud/ddl.source.sql.tmpl", **cc_values))
    _write(cc / "dml.pipeline.sql", render_template("cccloud/dml.pipeline.sql.tmpl", **cc_values))
    _write(cc / "Makefile", render_template("cccloud/Makefile.tmpl", **cc_values))


def _scaffold_oss_flink(demo_dir: Path, spec: DemoSpec, values: dict[str, str]) -> None:
    oss = demo_dir / "oss-flink"
    oss_values = {**values, "kafka_topic": spec.primary_topic}
    _write(oss / "README.md", render_template("oss-flink/README.md.tmpl", **oss_values))
    _write(oss / "docker-compose.yml", render_template("oss-flink/docker-compose.yml.tmpl", **oss_values))
    _write(oss / "scripts" / "run_demo.sh", render_template("oss-flink/scripts/run_demo.sh.tmpl", **oss_values))
    run_sh = oss / "scripts" / "run_demo.sh"
    run_sh.chmod(run_sh.stat().st_mode | 0o111)


def _scaffold_cp_flink_stub(demo_dir: Path, values: dict[str, str]) -> None:
    content = f"""# {values['demo_title']} — Confluent Platform Flink

## Goal

Confluent Platform Flink deployment variant for `{values['demo_name']}`.

## Status

WIP — scaffold stub only. Copy patterns from an existing `cp-flink/` demo under `e2e-demos/`.

## How to run

1. Apply CP/K8s infrastructure (see `deployment/kubernetes/`).
2. Deploy Flink SQL or Table API jobs from this folder once implemented.
"""
    _write(demo_dir / "cp-flink" / "README.md", content)
