"""Assemble tools for the jump-start agent."""
from __future__ import annotations

from pathlib import Path

from agno.tools import tool

from jump_start.manifest import generate_manifest_json
from jump_start.scaffold import DEFAULT_OUTPUT_PARENT, REPO_ROOT, DemoSpec, scaffold_demo
from jump_start.templates import list_template_files
from jump_start.validate import validate_demo

_PACKAGE_ROOT = Path(__file__).resolve().parents[2]
REFERENCE_DIR = _PACKAGE_ROOT.parent / "reference"

REFERENCE_FILES = {
    "confluent-flink-sql": "confluent-flink-sql.md",
    "deploy-manifest": "deploy-manifest.md",
    "local-docker": "local-docker.md",
    "use-case-templates": "use-case-templates.md",
    "producer-python": "producer-python.md",
}


def _resolve_repo_path(path: str) -> Path:
    """Resolve a path relative to flink-studies repo root (not agent cwd)."""
    candidate = Path(path).expanduser()
    if not candidate.is_absolute():
        candidate = (REPO_ROOT / candidate).resolve()
    else:
        candidate = candidate.resolve()
    return candidate


def _resolve_e2e_path(path: str) -> tuple[Path | None, str | None]:
    """Resolve and validate a path under flink-studies/e2e-demos/."""
    if not path.strip():
        return None, "Path is required."
    candidate = _resolve_repo_path(path)
    e2e_root = DEFAULT_OUTPUT_PARENT.resolve()
    try:
        candidate.relative_to(e2e_root)
    except ValueError:
        return None, (
            f"Path must be under {e2e_root}. Got {candidate}. "
            "Use repo-relative paths like e2e-demos/<name>/ or e2e-demos/<name>/cccloud."
        )
    return candidate, None


def _resolve_output_dir(output_path: str) -> tuple[Path | None, str | None]:
    """Resolve scaffold output under flink-studies/e2e-demos/."""
    if not output_path.strip():
        return None, None
    return _resolve_e2e_path(output_path)


def create_demo_tools():
    @tool(requires_confirmation=True)
    def scaffold_demo_tool(
        name: str,
        domain: str,
        topics: str,
        targets: str = "cccloud,oss-flink",
        entities: str = "",
        description: str = "",
        output_path: str = "",
        overwrite: bool = True,
    ) -> str:
        """Create foundational e2e demo files under e2e-demos/.

        Args:
            name: Demo slug (e.g. order-tracking)
            domain: Business domain (e.g. retail)
            topics: Comma-separated Kafka topic names
            targets: Comma-separated deployment targets: cccloud, oss-flink, cp-flink
            entities: Optional comma-separated table entity names (defaults from topics)
            description: Demo description for README
            output_path: Optional repo-relative path under e2e-demos/ (default: e2e-demos/<name>/)
            overwrite: When True (default), update an existing demo (e.g. add oss-flink in a later session)
        """
        topic_list = [t.strip() for t in topics.split(",") if t.strip()]
        target_list = [t.strip() for t in targets.split(",") if t.strip()]
        entity_list = [e.strip() for e in entities.split(",") if e.strip()] if entities else []

        output_dir, err = _resolve_output_dir(output_path)
        if err:
            return err
        spec = DemoSpec(
            name=name,
            domain=domain,
            targets=target_list,
            topics=topic_list,
            entities=entity_list,
            description=description,
            output_dir=output_dir,
        )
        demo_dir = spec.demo_dir
        existed = demo_dir.exists() and any(demo_dir.iterdir())
        try:
            scaffold_demo(spec, overwrite=overwrite)
        except FileExistsError as exc:
            return str(exc)
        action = "Updated" if existed else "Created"
        return (
            f"{action} demo at {demo_dir}\n"
            f"Targets: {', '.join(target_list)}\n"
            f"Topics: {', '.join(topic_list)}"
        )

    @tool
    def generate_deploy_manifest(cccloud_path: str, prefix: str = "") -> str:
        """Generate deploy_manifest.json for a cccloud SQL folder.

        Args:
            cccloud_path: Repo-relative path to cccloud/ folder (e2e-demos/<name>/cccloud)
            prefix: Optional statement name prefix (defaults to folder name)
        """
        sql_dir, err = _resolve_e2e_path(cccloud_path)
        if err:
            return err
        if not sql_dir.is_dir():
            return f"SQL directory not found: {sql_dir}"
        text = generate_manifest_json(
            sql_dir,
            prefix=prefix or None,
            overwrite=True,
        )
        return f"Wrote {sql_dir / 'deploy_manifest.json'}\n\n{text}"

    @tool
    def validate_demo_tool(demo_path: str) -> str:
        """Validate scaffolded demo structure and CC Flink SQL conventions.

        Args:
            demo_path: Repo-relative path to demo root (e2e-demos/<name>/)
        """
        demo_dir, err = _resolve_e2e_path(demo_path)
        if err:
            return err
        result = validate_demo(demo_dir)
        return result.summary()

    @tool
    def list_templates() -> str:
        """List available scaffold template files."""
        files = list_template_files()
        if not files:
            return "No templates found."
        return "Templates:\n" + "\n".join(f"- {f}" for f in files)

    @tool
    def list_use_cases() -> str:
        """List preset use-case templates (fraud, IoT, orders, analytics)."""
        path = REFERENCE_DIR / "use-case-templates.md"
        if not path.is_file():
            return "use-case-templates.md not found"
        return path.read_text(encoding="utf-8")

    @tool
    def read_reference(doc_name: str) -> str:
        """Load a reference document by name.

        Args:
            doc_name: One of: confluent-flink-sql, deploy-manifest, local-docker, use-case-templates, producer-python
        """
        key = doc_name.lower().replace("_", "-").replace(".md", "")
        filename = REFERENCE_FILES.get(key)
        if not filename:
            available = ", ".join(sorted(REFERENCE_FILES))
            return f"Unknown reference {doc_name!r}. Available: {available}"
        path = REFERENCE_DIR / filename
        if not path.is_file():
            return f"Reference file not found: {path}"
        return path.read_text(encoding="utf-8")

    return [
        scaffold_demo_tool,
        generate_deploy_manifest,
        validate_demo_tool,
        list_templates,
        list_use_cases,
        read_reference,
    ]


def build_agent_tools():
    return create_demo_tools()
