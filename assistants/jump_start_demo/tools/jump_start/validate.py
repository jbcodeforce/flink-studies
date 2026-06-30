"""Validate scaffolded demo structure."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class ValidationIssue:
    level: str  # error | warning
    message: str


@dataclass
class ValidationResult:
    demo_dir: Path
    issues: list[ValidationIssue] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not any(i.level == "error" for i in self.issues)

    def summary(self) -> str:
        lines = [f"Validation: {self.demo_dir}"]
        if self.ok and not self.issues:
            lines.append("PASS — no issues")
        else:
            for issue in self.issues:
                lines.append(f"  [{issue.level.upper()}] {issue.message}")
            lines.append("PASS" if self.ok else "FAIL")
        return "\n".join(lines)


def validate_demo(demo_dir: Path) -> ValidationResult:
    demo_dir = demo_dir.resolve()
    result = ValidationResult(demo_dir=demo_dir)

    if not demo_dir.is_dir():
        result.issues.append(ValidationIssue("error", f"Demo directory not found: {demo_dir}"))
        return result

    if not (demo_dir / "README.md").is_file():
        result.issues.append(ValidationIssue("error", "Missing root README.md"))

    cc = demo_dir / "cccloud"
    if cc.is_dir():
        _validate_cccloud(cc, result)

    oss = demo_dir / "oss-flink"
    if oss.is_dir():
        _validate_oss_flink(oss, result)

    cp = demo_dir / "cp-flink"
    if cp.is_dir():
        if not (cp / "README.md").is_file():
            result.issues.append(ValidationIssue("warning", "cp-flink/ missing README.md"))

    if not any((demo_dir / t).is_dir() for t in ("cccloud", "oss-flink", "cp-flink")):
        result.issues.append(
            ValidationIssue("error", "No deployment folder (cccloud/, oss-flink/, or cp-flink/)")
        )

    return result


def _validate_cccloud(cc: Path, result: ValidationResult) -> None:
    if not (cc / "README.md").is_file():
        result.issues.append(ValidationIssue("error", "cccloud/ missing README.md"))

    ddl_files = list(cc.glob("ddl.*.sql"))
    if not ddl_files:
        result.issues.append(ValidationIssue("error", "cccloud/ has no ddl.*.sql files"))

    for ddl in ddl_files:
        text = ddl.read_text(encoding="utf-8").lower()
        if "key.format" not in text:
            result.issues.append(
                ValidationIssue("warning", f"{ddl.name}: missing key.format (CC Flink requirement)")
            )
        if "distributed by" not in text and "primary key" not in text:
            result.issues.append(
                ValidationIssue(
                    "warning",
                    f"{ddl.name}: no DISTRIBUTED BY or PRIMARY KEY (CC Flink requirement)",
                )
            )

    manifest = cc / "deploy_manifest.json"
    if not manifest.is_file():
        result.issues.append(
            ValidationIssue(
                "warning",
                "cccloud/ missing deploy_manifest.json — run: jump-start manifest --path .../cccloud",
            )
        )


def _validate_oss_flink(oss: Path, result: ValidationResult) -> None:
    if not (oss / "README.md").is_file():
        result.issues.append(ValidationIssue("error", "oss-flink/ missing README.md"))
    if not (oss / "docker-compose.yml").is_file():
        result.issues.append(ValidationIssue("error", "oss-flink/ missing docker-compose.yml"))
    run_sh = oss / "scripts" / "run_demo.sh"
    if not run_sh.is_file():
        result.issues.append(ValidationIssue("warning", "oss-flink/scripts/run_demo.sh missing"))
