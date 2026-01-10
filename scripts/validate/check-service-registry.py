#!/usr/bin/env python3
"""
A.R.C. Platform - SERVICE.MD Registry Validator

Purpose: Validate SERVICE.MD against actual directory structure
Usage: python scripts/validate/check-service-registry.py [--strict] [--json]
Exit: 0=all pass, 1=validation errors found
"""

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


@dataclass
class ValidationIssue:
    """A validation issue found during checking."""
    severity: str  # error, warning, info
    category: str  # missing_dir, orphan_dir, missing_dockerfile, etc.
    message: str
    service: str = ""
    path: str = ""


@dataclass
class ValidationResult:
    """Result of SERVICE.MD validation."""
    valid: bool
    issues: list[ValidationIssue] = field(default_factory=list)
    services_checked: int = 0
    directories_checked: int = 0


def find_repo_root() -> Path:
    """Find repository root by looking for SERVICE.MD."""
    current = Path(__file__).resolve()
    for parent in [current] + list(current.parents):
        if (parent / "SERVICE.MD").exists():
            return parent
    raise FileNotFoundError("Could not find repository root (SERVICE.MD not found)")


def parse_service_table(content: str) -> list[dict[str, str]]:
    """Parse the Master Service Table from SERVICE.MD."""
    services = []

    # Find table rows (lines starting with |)
    in_table = False
    header_found = False

    for line in content.split("\n"):
        line = line.strip()

        # Detect table start (header row)
        if "| Service" in line and "Codename" in line:
            in_table = True
            header_found = True
            continue

        # Skip separator row
        if in_table and line.startswith("|") and "---" in line:
            continue

        # Parse data rows
        if in_table and line.startswith("|") and header_found:
            # Split by | and clean up
            parts = [p.strip() for p in line.split("|")]
            parts = [p for p in parts if p]  # Remove empty parts

            if len(parts) >= 6:
                service_name = re.sub(r"\*\*|\`", "", parts[0])  # Remove markdown
                arc_image = re.sub(r"\`", "", parts[1])
                service_type = parts[2]
                upstream = re.sub(r"\`", "", parts[3])
                codename = re.sub(r"\*\*", "", parts[4])

                services.append({
                    "name": service_name,
                    "image": arc_image,
                    "type": service_type,
                    "upstream": upstream,
                    "codename": codename,
                })

        # End table detection
        if in_table and not line.startswith("|") and line:
            if "---" in line:
                in_table = False

    return services


def get_expected_path(service: dict[str, str], repo_root: Path) -> Path | None:
    """Determine expected directory path for a service."""
    upstream = service.get("upstream", "")
    service_type = service.get("type", "").upper()
    codename = service.get("codename", "").lower()
    image = service.get("image", "")

    # Services with local source (./path)
    if upstream.startswith("./"):
        rel_path = upstream[2:]  # Remove ./
        return repo_root / rel_path

    # Infrastructure services from upstream images - check by codename
    codename_to_path = {
        "heimdall": "core/gateway/traefik",
        "oracle": "core/persistence/postgres",
        "sonic": "core/caching/redis",
        "flash": "core/messaging/ephemeral/nats",
        "strange": "core/messaging/durable/pulsar",
        "widow": "core/telemetry",
        "fury": "core/secrets/infisical",
        "watson": "plugins/observability/logging/loki",
        "house": "plugins/observability/metrics/prometheus",
        "columbo": "plugins/observability/tracing/jaeger",
        "friday": "plugins/observability/visualization/grafana",
        "jarvis": "plugins/security/kratos",
        "mystique": "core/feature-flags/unleash",
    }

    codename_lower = codename.lower()
    if codename_lower in codename_to_path:
        return repo_root / codename_to_path[codename_lower]

    # Check services/ directory for arc-* images
    if image.startswith("arc-"):
        # Try common patterns
        potential_paths = [
            repo_root / "services" / image,
            repo_root / "services" / f"arc-{codename_lower}-brain",
            repo_root / "services" / f"arc-{codename_lower}-voice",
            repo_root / "services" / "utilities" / codename_lower,
        ]
        for path in potential_paths:
            if path.exists():
                return path

    return None


def find_actual_service_dirs(repo_root: Path) -> set[Path]:
    """Find all actual service directories in the repo."""
    service_dirs = set()

    # Check core/
    core_path = repo_root / "core"
    if core_path.exists():
        for item in core_path.rglob("*"):
            if item.is_dir() and (
                (item / "Dockerfile").exists() or
                (item / "docker-compose.yml").exists() or
                item.name in ["traefik", "postgres", "redis", "nats", "pulsar", "infisical", "unleash"]
            ):
                service_dirs.add(item)

    # Check plugins/
    plugins_path = repo_root / "plugins"
    if plugins_path.exists():
        for item in plugins_path.rglob("*"):
            if item.is_dir() and (
                (item / "Dockerfile").exists() or
                item.name in ["loki", "prometheus", "jaeger", "grafana", "kratos"]
            ):
                service_dirs.add(item)

    # Check services/
    services_path = repo_root / "services"
    if services_path.exists():
        for item in services_path.iterdir():
            if item.is_dir() and item.name.startswith("arc-"):
                service_dirs.add(item)
        # Also check services/utilities/
        utilities_path = services_path / "utilities"
        if utilities_path.exists():
            for item in utilities_path.iterdir():
                if item.is_dir():
                    service_dirs.add(item)

    return service_dirs


def validate_service_registry(repo_root: Path) -> ValidationResult:
    """Validate SERVICE.MD against actual directory structure."""
    result = ValidationResult(valid=True)

    service_md = repo_root / "SERVICE.MD"
    if not service_md.exists():
        result.valid = False
        result.issues.append(ValidationIssue(
            severity="error",
            category="missing_file",
            message="SERVICE.MD not found in repository root",
        ))
        return result

    content = service_md.read_text()
    services = parse_service_table(content)
    result.services_checked = len(services)

    # Track services we've validated
    validated_paths = set()

    # Check each service in the registry
    for service in services:
        service_type = service.get("type", "").upper()
        upstream = service.get("upstream", "")

        # Skip services that use external images (no local directory expected)
        if not upstream.startswith("./") and service_type == "INFRA":
            # Infrastructure services may or may not have local config
            expected = get_expected_path(service, repo_root)
            if expected and expected.exists():
                validated_paths.add(expected)
            continue

        # For local services, verify directory exists
        if upstream.startswith("./"):
            expected = get_expected_path(service, repo_root)
            if expected:
                validated_paths.add(expected)
                if not expected.exists():
                    result.valid = False
                    result.issues.append(ValidationIssue(
                        severity="error",
                        category="missing_directory",
                        message=f"Directory not found for service",
                        service=service.get("name", ""),
                        path=str(expected.relative_to(repo_root)),
                    ))
                elif not (expected / "Dockerfile").exists() and not any(expected.glob("*.py")):
                    result.issues.append(ValidationIssue(
                        severity="warning",
                        category="missing_dockerfile",
                        message=f"No Dockerfile found in service directory",
                        service=service.get("name", ""),
                        path=str(expected.relative_to(repo_root)),
                    ))

    # Find orphaned directories (exist but not in registry)
    actual_dirs = find_actual_service_dirs(repo_root)
    result.directories_checked = len(actual_dirs)

    for actual_dir in actual_dirs:
        # Check if this directory is tracked
        is_tracked = False
        for validated in validated_paths:
            try:
                if actual_dir == validated or validated in actual_dir.parents:
                    is_tracked = True
                    break
            except ValueError:
                pass

        if not is_tracked:
            # Check if it's a known service directory
            dir_name = actual_dir.name
            if dir_name.startswith("arc-") or dir_name in ["raymond", "sherlock", "scarlett", "piper"]:
                result.issues.append(ValidationIssue(
                    severity="info",
                    category="untracked_directory",
                    message=f"Service directory not found in SERVICE.MD registry",
                    path=str(actual_dir.relative_to(repo_root)),
                ))

    return result


def output_text(result: ValidationResult) -> None:
    """Output results as text."""
    print("\033[0;36m╔═══════════════════════════════════════════════════════════════════╗\033[0m")
    print("\033[0;36m║          A.R.C. SERVICE.MD Registry Validator                     ║\033[0m")
    print("\033[0;36m╚═══════════════════════════════════════════════════════════════════╝\033[0m")
    print()

    print(f"\033[0;34mServices in registry:\033[0m {result.services_checked}")
    print(f"\033[0;34mDirectories checked:\033[0m {result.directories_checked}")
    print()

    if not result.issues:
        print("\033[0;32m✅ No issues found - SERVICE.MD is synchronized!\033[0m")
        return

    # Group issues by severity
    errors = [i for i in result.issues if i.severity == "error"]
    warnings = [i for i in result.issues if i.severity == "warning"]
    infos = [i for i in result.issues if i.severity == "info"]

    if errors:
        print("\033[0;31m❌ Errors:\033[0m")
        for issue in errors:
            print(f"  • [{issue.category}] {issue.message}")
            if issue.service:
                print(f"    Service: {issue.service}")
            if issue.path:
                print(f"    Path: {issue.path}")
        print()

    if warnings:
        print("\033[0;33m⚠️  Warnings:\033[0m")
        for issue in warnings:
            print(f"  • [{issue.category}] {issue.message}")
            if issue.path:
                print(f"    Path: {issue.path}")
        print()

    if infos:
        print("\033[0;34mℹ️  Info:\033[0m")
        for issue in infos:
            print(f"  • [{issue.category}] {issue.message}")
            if issue.path:
                print(f"    Path: {issue.path}")
        print()

    # Summary
    print("\033[0;36m═══════════════════════════════════════════════════════════════════\033[0m")
    status = "\033[0;32m✅ PASS\033[0m" if result.valid else "\033[0;31m❌ FAIL\033[0m"
    print(f"Status: {status}")
    print(f"Errors: {len(errors)}, Warnings: {len(warnings)}, Info: {len(infos)}")


def output_json(result: ValidationResult) -> None:
    """Output results as JSON."""
    output: dict[str, Any] = {
        "valid": result.valid,
        "services_checked": result.services_checked,
        "directories_checked": result.directories_checked,
        "issues": [
            {
                "severity": i.severity,
                "category": i.category,
                "message": i.message,
                "service": i.service,
                "path": i.path,
            }
            for i in result.issues
        ],
        "summary": {
            "errors": sum(1 for i in result.issues if i.severity == "error"),
            "warnings": sum(1 for i in result.issues if i.severity == "warning"),
            "info": sum(1 for i in result.issues if i.severity == "info"),
        },
    }
    print(json.dumps(output, indent=2))


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Validate SERVICE.MD against directory structure"
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

    result = validate_service_registry(repo_root)

    # In strict mode, warnings become errors
    if args.strict:
        for issue in result.issues:
            if issue.severity == "warning":
                issue.severity = "error"
                result.valid = False

    if args.json:
        output_json(result)
    else:
        output_text(result)

    return 0 if result.valid else 1


if __name__ == "__main__":
    sys.exit(main())
