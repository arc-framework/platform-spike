#!/usr/bin/env python3
"""
A.R.C. Platform - Dockerfile Standards Validator

Purpose: Validate Dockerfiles follow A.R.C. Constitution security requirements
Usage: python scripts/validate/check-dockerfile-standards.py [--strict] [--json]
Exit: 0=all pass, 1=validation errors found

Checks:
- Non-root USER instruction present
- No :latest tags in FROM statements
- Multi-stage build pattern
- HEALTHCHECK instruction present
- Required OCI labels
"""

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


# Required OCI labels
REQUIRED_LABELS = [
    "org.opencontainers.image.title",
]

RECOMMENDED_LABELS = [
    "org.opencontainers.image.description",
    "org.opencontainers.image.version",
]

# A.R.C. specific labels
ARC_LABELS = [
    "arc.service.tier",
]


@dataclass
class DockerfileIssue:
    """An issue found in a Dockerfile."""
    severity: str  # error, warning, info
    rule: str
    message: str
    line: int = 0


@dataclass
class DockerfileResult:
    """Result of validating a single Dockerfile."""
    path: str
    valid: bool
    issues: list[DockerfileIssue] = field(default_factory=list)


@dataclass
class ValidationResult:
    """Overall validation result."""
    valid: bool
    dockerfiles: list[DockerfileResult] = field(default_factory=list)
    total_errors: int = 0
    total_warnings: int = 0


def find_repo_root() -> Path:
    """Find repository root."""
    current = Path(__file__).resolve()
    for parent in [current] + list(current.parents):
        if (parent / "SERVICE.MD").exists() or (parent / "Makefile").exists():
            return parent
    raise FileNotFoundError("Could not find repository root")


def find_dockerfiles(repo_root: Path) -> list[Path]:
    """Find all Dockerfiles in the repository."""
    dockerfiles = []
    for dockerfile in repo_root.rglob("Dockerfile"):
        # Skip node_modules, .git, vendor
        parts = dockerfile.parts
        if any(p in parts for p in ["node_modules", ".git", "vendor", "__pycache__"]):
            continue
        dockerfiles.append(dockerfile)
    return sorted(dockerfiles)


def parse_dockerfile(content: str) -> dict[str, Any]:
    """Parse Dockerfile content into structured data."""
    result = {
        "from_statements": [],
        "user_statements": [],
        "healthcheck": None,
        "labels": {},
        "stages": [],
        "lines": content.split("\n"),
    }

    current_stage = None
    line_num = 0

    for line in result["lines"]:
        line_num += 1
        stripped = line.strip()

        # Skip comments and empty lines
        if not stripped or stripped.startswith("#"):
            continue

        # FROM statements
        from_match = re.match(r"^FROM\s+(\S+)(?:\s+AS\s+(\S+))?", stripped, re.IGNORECASE)
        if from_match:
            image = from_match.group(1)
            stage = from_match.group(2)
            result["from_statements"].append({
                "image": image,
                "stage": stage,
                "line": line_num,
            })
            current_stage = stage
            result["stages"].append(stage or f"stage_{len(result['stages'])}")

        # USER statements
        user_match = re.match(r"^USER\s+(\S+)", stripped, re.IGNORECASE)
        if user_match:
            result["user_statements"].append({
                "user": user_match.group(1),
                "line": line_num,
                "stage": current_stage,
            })

        # HEALTHCHECK
        if stripped.upper().startswith("HEALTHCHECK"):
            result["healthcheck"] = {
                "line": line_num,
                "content": stripped,
            }

        # LABEL statements
        label_match = re.match(r"^LABEL\s+(.+)$", stripped, re.IGNORECASE)
        if label_match:
            label_content = label_match.group(1)
            # Parse key=value or key="value" pairs
            for match in re.finditer(r'([a-z._-]+)\s*=\s*["\']?([^"\']+)["\']?', label_content, re.IGNORECASE):
                result["labels"][match.group(1)] = match.group(2)

    return result


def validate_dockerfile(dockerfile_path: Path, repo_root: Path) -> DockerfileResult:
    """Validate a single Dockerfile against A.R.C. standards."""
    rel_path = str(dockerfile_path.relative_to(repo_root))
    result = DockerfileResult(path=rel_path, valid=True)

    try:
        content = dockerfile_path.read_text()
    except Exception as e:
        result.valid = False
        result.issues.append(DockerfileIssue(
            severity="error",
            rule="read_error",
            message=f"Could not read Dockerfile: {e}",
        ))
        return result

    parsed = parse_dockerfile(content)

    # Rule 1: No :latest tags (Security - immutable builds)
    for from_stmt in parsed["from_statements"]:
        image = from_stmt["image"]
        if image.endswith(":latest") or ":" not in image:
            # Exception for build args like ${BASE_IMAGE}
            if not image.startswith("$"):
                result.issues.append(DockerfileIssue(
                    severity="warning",
                    rule="no_latest_tag",
                    message=f"Avoid :latest tag or untagged images: {image}",
                    line=from_stmt["line"],
                ))

    # Rule 2: Non-root USER (Security - Constitution VIII)
    has_non_root_user = False
    for user_stmt in parsed["user_statements"]:
        user = user_stmt["user"].lower()
        if user not in ["root", "0"]:
            has_non_root_user = True
            break

    if not has_non_root_user:
        result.valid = False
        result.issues.append(DockerfileIssue(
            severity="error",
            rule="non_root_user",
            message="Dockerfile must have USER instruction with non-root user (Constitution VIII)",
        ))

    # Rule 3: HEALTHCHECK present (Resilience - Constitution VII)
    if not parsed["healthcheck"]:
        result.issues.append(DockerfileIssue(
            severity="warning",
            rule="healthcheck_required",
            message="HEALTHCHECK instruction recommended (Constitution VII)",
        ))

    # Rule 4: Multi-stage build (Optimization)
    # Only check for services, not base images
    if "base" not in rel_path.lower() and len(parsed["stages"]) < 2:
        result.issues.append(DockerfileIssue(
            severity="info",
            rule="multi_stage_build",
            message="Consider using multi-stage build to reduce image size",
        ))

    # Rule 5: Required labels
    for label in REQUIRED_LABELS:
        if label not in parsed["labels"]:
            result.issues.append(DockerfileIssue(
                severity="warning",
                rule="required_label",
                message=f"Missing required OCI label: {label}",
            ))

    # Rule 6: Recommended labels
    for label in RECOMMENDED_LABELS:
        if label not in parsed["labels"]:
            result.issues.append(DockerfileIssue(
                severity="info",
                rule="recommended_label",
                message=f"Missing recommended label: {label}",
            ))

    # Rule 7: Check for potential security issues
    for i, line in enumerate(parsed["lines"], 1):
        stripped = line.strip()

        # Warn about curl | bash pattern
        if re.search(r"curl.*\|.*sh", stripped, re.IGNORECASE) or \
           re.search(r"wget.*\|.*sh", stripped, re.IGNORECASE):
            result.issues.append(DockerfileIssue(
                severity="warning",
                rule="curl_pipe_bash",
                message="Avoid curl/wget piped to shell - use package managers",
                line=i,
            ))

        # Warn about ADD with URLs (prefer COPY + explicit download)
        if re.match(r"^ADD\s+https?://", stripped, re.IGNORECASE):
            result.issues.append(DockerfileIssue(
                severity="info",
                rule="add_url",
                message="Prefer COPY with explicit download for transparency",
                line=i,
            ))

    return result


def validate_all_dockerfiles(repo_root: Path) -> ValidationResult:
    """Validate all Dockerfiles in the repository."""
    result = ValidationResult(valid=True)

    dockerfiles = find_dockerfiles(repo_root)

    for dockerfile in dockerfiles:
        df_result = validate_dockerfile(dockerfile, repo_root)
        result.dockerfiles.append(df_result)

        if not df_result.valid:
            result.valid = False

        result.total_errors += sum(1 for i in df_result.issues if i.severity == "error")
        result.total_warnings += sum(1 for i in df_result.issues if i.severity == "warning")

    return result


def output_text(result: ValidationResult) -> None:
    """Output results as text."""
    print("\033[0;36m╔═══════════════════════════════════════════════════════════════════╗\033[0m")
    print("\033[0;36m║          A.R.C. Dockerfile Standards Validator                    ║\033[0m")
    print("\033[0;36m╚═══════════════════════════════════════════════════════════════════╝\033[0m")
    print()

    print(f"\033[0;34mDockerfiles checked:\033[0m {len(result.dockerfiles)}")
    print()

    for df_result in result.dockerfiles:
        if not df_result.issues:
            print(f"\033[0;32m✓\033[0m {df_result.path}")
            continue

        errors = [i for i in df_result.issues if i.severity == "error"]
        warnings = [i for i in df_result.issues if i.severity == "warning"]
        infos = [i for i in df_result.issues if i.severity == "info"]

        status = "\033[0;31m✗\033[0m" if errors else "\033[0;33m⚠\033[0m" if warnings else "\033[0;34mℹ\033[0m"
        print(f"{status} {df_result.path}")

        for issue in df_result.issues:
            if issue.severity == "error":
                icon = "\033[0;31m  ✗\033[0m"
            elif issue.severity == "warning":
                icon = "\033[0;33m  ⚠\033[0m"
            else:
                icon = "\033[0;34m  ℹ\033[0m"

            line_info = f" (line {issue.line})" if issue.line else ""
            print(f"{icon} [{issue.rule}] {issue.message}{line_info}")

        print()

    # Summary
    print("\033[0;36m═══════════════════════════════════════════════════════════════════\033[0m")
    status = "\033[0;32m✅ PASS\033[0m" if result.valid else "\033[0;31m❌ FAIL\033[0m"
    print(f"Status: {status}")
    print(f"Dockerfiles: {len(result.dockerfiles)}, Errors: {result.total_errors}, Warnings: {result.total_warnings}")


def output_json(result: ValidationResult) -> None:
    """Output results as JSON."""
    output: dict[str, Any] = {
        "valid": result.valid,
        "total_dockerfiles": len(result.dockerfiles),
        "total_errors": result.total_errors,
        "total_warnings": result.total_warnings,
        "dockerfiles": [
            {
                "path": df.path,
                "valid": df.valid,
                "issues": [
                    {
                        "severity": i.severity,
                        "rule": i.rule,
                        "message": i.message,
                        "line": i.line,
                    }
                    for i in df.issues
                ],
            }
            for df in result.dockerfiles
        ],
    }
    print(json.dumps(output, indent=2))


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Validate Dockerfiles follow A.R.C. Constitution standards"
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output results as JSON",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Treat warnings as errors",
    )
    args = parser.parse_args()

    try:
        repo_root = find_repo_root()
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    result = validate_all_dockerfiles(repo_root)

    # In strict mode, warnings become errors
    if args.strict:
        for df_result in result.dockerfiles:
            for issue in df_result.issues:
                if issue.severity == "warning":
                    issue.severity = "error"
                    df_result.valid = False
                    result.valid = False
                    result.total_errors += 1
                    result.total_warnings -= 1

    if args.json:
        output_json(result)
    else:
        output_text(result)

    return 0 if result.valid else 1


if __name__ == "__main__":
    sys.exit(main())
