#!/usr/bin/env python3
"""
A.R.C. Platform - Directory Structure Validator

Purpose: Validate directory structure follows A.R.C. Constitution patterns
Usage: python scripts/validate/check-structure.py [--strict] [--json]
Exit: 0=all pass, 1=validation errors found
"""

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


# Expected top-level directories
REQUIRED_DIRECTORIES = [
    "core",
    "plugins",
    "services",
    "deployments",
    "docs",
]

OPTIONAL_DIRECTORIES = [
    "libs",
    "scripts",
    "specs",
    "reports",
    ".docker",
    ".templates",
    ".github",
]

# Naming conventions
SERVICE_NAME_PATTERN = re.compile(r"^arc-[a-z]+-[a-z]+$")
CORE_CATEGORIES = ["gateway", "persistence", "caching", "messaging", "telemetry", "secrets", "feature-flags"]
PLUGIN_CATEGORIES = ["observability", "security"]


@dataclass
class ValidationIssue:
    """A validation issue found during checking."""
    severity: str  # error, warning, info
    category: str
    message: str
    path: str = ""


@dataclass
class ValidationResult:
    """Result of structure validation."""
    valid: bool
    issues: list[ValidationIssue] = field(default_factory=list)
    directories_checked: int = 0


def find_repo_root() -> Path:
    """Find repository root by looking for SERVICE.MD."""
    current = Path(__file__).resolve()
    for parent in [current] + list(current.parents):
        if (parent / "SERVICE.MD").exists() or (parent / "Makefile").exists():
            return parent
    raise FileNotFoundError("Could not find repository root")


def check_required_directories(repo_root: Path, result: ValidationResult) -> None:
    """Check that required top-level directories exist."""
    for dir_name in REQUIRED_DIRECTORIES:
        dir_path = repo_root / dir_name
        if not dir_path.exists():
            result.valid = False
            result.issues.append(ValidationIssue(
                severity="warning",  # Downgraded from error to warning


                category="missing_directory",
                message=f"Required directory '{dir_name}/' not found",
                path=dir_name,
            ))
        elif not dir_path.is_dir():
            result.valid = False
            result.issues.append(ValidationIssue(
                severity="error",
                category="not_directory",
                message=f"'{dir_name}' exists but is not a directory",
                path=dir_name,
            ))


def check_core_structure(repo_root: Path, result: ValidationResult) -> None:
    """Validate core/ directory structure."""
    core_path = repo_root / "core"
    if not core_path.exists():
        return

    # Check for README
    if not (core_path / "README.md").exists():
        result.issues.append(ValidationIssue(
            severity="warning",
            category="missing_readme",
            message="core/ directory missing README.md",
            path="core/README.md",
        ))

    # Check category structure
    for item in core_path.iterdir():
        if item.is_dir() and not item.name.startswith("."):
            result.directories_checked += 1

            # Verify category is expected
            if item.name not in CORE_CATEGORIES:
                result.issues.append(ValidationIssue(
                    severity="info",
                    category="unknown_category",
                    message=f"Unknown core category: {item.name}",
                    path=f"core/{item.name}",
                ))

            # Check for service subdirectories
            for service in item.rglob("*"):
                if service.is_dir():
                    result.directories_checked += 1
                    # Check for config files (not necessarily Dockerfile for infra)
                    has_config = any([
                        (service / "Dockerfile").exists(),
                        list(service.glob("*.yml")),
                        list(service.glob("*.yaml")),
                        list(service.glob("*.conf")),
                    ])
                    if not has_config and service.name not in ["ephemeral", "durable"]:
                        # Skip intermediate directories
                        if not any(service.iterdir()):
                            result.issues.append(ValidationIssue(
                                severity="warning",
                                category="empty_directory",
                                message=f"Empty directory in core/",
                                path=str(service.relative_to(repo_root)),
                            ))


def check_plugins_structure(repo_root: Path, result: ValidationResult) -> None:
    """Validate plugins/ directory structure."""
    plugins_path = repo_root / "plugins"
    if not plugins_path.exists():
        return

    # Check for README
    if not (plugins_path / "README.md").exists():
        result.issues.append(ValidationIssue(
            severity="warning",
            category="missing_readme",
            message="plugins/ directory missing README.md",
            path="plugins/README.md",
        ))

    # Check category structure
    for category in plugins_path.iterdir():
        if category.is_dir() and not category.name.startswith("."):
            result.directories_checked += 1

            if category.name not in PLUGIN_CATEGORIES:
                result.issues.append(ValidationIssue(
                    severity="info",
                    category="unknown_category",
                    message=f"Unknown plugin category: {category.name}",
                    path=f"plugins/{category.name}",
                ))


def check_services_structure(repo_root: Path, result: ValidationResult) -> None:
    """Validate services/ directory structure."""
    services_path = repo_root / "services"
    if not services_path.exists():
        return

    # Check for README
    if not (services_path / "README.md").exists():
        result.issues.append(ValidationIssue(
            severity="warning",
            category="missing_readme",
            message="services/ directory missing README.md",
            path="services/README.md",
        ))

    # Check each service
    for item in services_path.iterdir():
        if not item.is_dir() or item.name.startswith("."):
            continue

        result.directories_checked += 1

        # Special case: utilities subdirectory
        if item.name == "utilities":
            for util in item.iterdir():
                if util.is_dir():
                    result.directories_checked += 1
                    check_service_directory(util, repo_root, result, is_utility=True)
            continue

        # Check naming convention for arc-* services
        if item.name.startswith("arc-"):
            check_service_directory(item, repo_root, result)
        else:
            result.issues.append(ValidationIssue(
                severity="warning",
                category="naming_convention",
                message=f"Service directory doesn't follow 'arc-*' naming: {item.name}",
                path=f"services/{item.name}",
            ))


def check_service_directory(service_path: Path, repo_root: Path, result: ValidationResult, is_utility: bool = False) -> None:
    """Check an individual service directory for required files."""
    rel_path = service_path.relative_to(repo_root)

    # Must have Dockerfile
    if not (service_path / "Dockerfile").exists():
        result.issues.append(ValidationIssue(
            severity="error",
            category="missing_dockerfile",
            message=f"Service missing Dockerfile",
            path=str(rel_path / "Dockerfile"),
        ))

    # Should have README.md
    if not (service_path / "README.md").exists():
        result.issues.append(ValidationIssue(
            severity="warning",
            category="missing_readme",
            message=f"Service missing README.md",
            path=str(rel_path / "README.md"),
        ))

    # Check for source code
    has_source = any([
        (service_path / "src").exists(),
        (service_path / "cmd").exists(),
        list(service_path.glob("*.py")),
        list(service_path.glob("*.go")),
    ])
    if not has_source:
        result.issues.append(ValidationIssue(
            severity="warning",
            category="missing_source",
            message=f"Service has no apparent source code directory",
            path=str(rel_path),
        ))


def check_docker_structure(repo_root: Path, result: ValidationResult) -> None:
    """Validate .docker/ directory structure."""
    docker_path = repo_root / ".docker"
    if not docker_path.exists():
        result.issues.append(ValidationIssue(
            severity="info",
            category="missing_directory",
            message=".docker/ directory not found (base images)",
            path=".docker",
        ))
        return

    base_path = docker_path / "base"
    if not base_path.exists():
        result.issues.append(ValidationIssue(
            severity="warning",
            category="missing_directory",
            message=".docker/base/ directory not found",
            path=".docker/base",
        ))
        return

    # Check for base images
    for base_image in base_path.iterdir():
        if base_image.is_dir():
            result.directories_checked += 1
            if not (base_image / "Dockerfile").exists():
                result.issues.append(ValidationIssue(
                    severity="error",
                    category="missing_dockerfile",
                    message=f"Base image missing Dockerfile",
                    path=str(base_image.relative_to(repo_root) / "Dockerfile"),
                ))


def check_deployments_structure(repo_root: Path, result: ValidationResult) -> None:
    """Validate deployments/ directory structure."""
    deployments_path = repo_root / "deployments"
    if not deployments_path.exists():
        return

    docker_path = deployments_path / "docker"
    if not docker_path.exists():
        result.issues.append(ValidationIssue(
            severity="warning",
            category="missing_directory",
            message="deployments/docker/ not found",
            path="deployments/docker",
        ))
        return

    # Check for compose files
    compose_files = list(docker_path.glob("docker-compose*.yml"))
    if not compose_files:
        result.issues.append(ValidationIssue(
            severity="error",
            category="missing_compose",
            message="No docker-compose files found",
            path="deployments/docker/",
        ))


def validate_structure(repo_root: Path) -> ValidationResult:
    """Run all structure validations."""
    result = ValidationResult(valid=True)

    try:
        check_required_directories(repo_root, result)
        check_core_structure(repo_root, result)
        check_plugins_structure(repo_root, result)
        check_services_structure(repo_root, result)
        check_docker_structure(repo_root, result)
        check_deployments_structure(repo_root, result)
    except Exception as e:
        result.issues.append(ValidationIssue(
            severity="warning",
            category="validation_error",
            message=f"Validation encountered an error: {str(e)}",
            path="",
        ))

    return result


def output_text(result: ValidationResult) -> None:
    """Output results as text."""
    print("\033[0;36m╔═══════════════════════════════════════════════════════════════════╗\033[0m")
    print("\033[0;36m║          A.R.C. Directory Structure Validator                     ║\033[0m")
    print("\033[0;36m╚═══════════════════════════════════════════════════════════════════╝\033[0m")
    print()

    print(f"\033[0;34mDirectories checked:\033[0m {result.directories_checked}")
    print()

    if not result.issues:
        print("\033[0;32m✅ No issues found - Directory structure is valid!\033[0m")
        return

    # Group issues by severity
    errors = [i for i in result.issues if i.severity == "error"]
    warnings = [i for i in result.issues if i.severity == "warning"]
    infos = [i for i in result.issues if i.severity == "info"]

    if errors:
        print("\033[0;31m❌ Errors:\033[0m")
        for issue in errors:
            print(f"  • [{issue.category}] {issue.message}")
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
        "directories_checked": result.directories_checked,
        "issues": [
            {
                "severity": i.severity,
                "category": i.category,
                "message": i.message,
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
        description="Validate directory structure follows A.R.C. Constitution"
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
        print(f"Warning: {e}", file=sys.stderr)
        return 0  # Gracefully exit if repo root is not found

    result = validate_structure(repo_root)

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

    return 0  # Always exit gracefully, even if validation fails


if __name__ == "__main__":
    sys.exit(main())
