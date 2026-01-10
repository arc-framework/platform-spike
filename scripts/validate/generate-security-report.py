#!/usr/bin/env python3
"""
A.R.C. Platform - Security Compliance Report Generator

Purpose: Generate comprehensive security compliance report for all Docker images
Usage: python scripts/validate/generate-security-report.py [--output FILE]
Exit: 0=pass, 1=issues found, 2=error
"""

import argparse
import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any


def run_command(cmd: list[str]) -> tuple[int, str, str]:
    """Run a command and return exit code, stdout, stderr."""
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return 2, "", "Command timed out"
    except FileNotFoundError:
        return 2, "", f"Command not found: {cmd[0]}"


def get_dockerfiles(repo_root: Path) -> list[Path]:
    """Find all Dockerfiles in the repository."""
    dockerfiles = []
    for dockerfile in repo_root.rglob("Dockerfile"):
        # Skip common exclusions
        parts = dockerfile.parts
        if any(p in parts for p in ["node_modules", ".git", "vendor"]):
            continue
        dockerfiles.append(dockerfile)
    return sorted(dockerfiles)


def get_docker_images() -> list[str]:
    """Get list of arc-* Docker images."""
    code, stdout, _ = run_command(
        ["docker", "images", "--format", "{{.Repository}}:{{.Tag}}"]
    )
    if code != 0:
        return []
    return [img for img in stdout.strip().split("\n") if img.startswith("arc-") and "<none>" not in img]


def run_hadolint(dockerfile: Path, config: Path | None = None) -> dict[str, Any]:
    """Run hadolint on a Dockerfile and return results."""
    cmd = ["hadolint", "--format", "json"]
    if config and config.exists():
        cmd.extend(["--config", str(config)])
    cmd.append(str(dockerfile))

    code, stdout, stderr = run_command(cmd)

    try:
        issues = json.loads(stdout) if stdout.strip() else []
    except json.JSONDecodeError:
        issues = []

    return {
        "file": str(dockerfile),
        "passed": code == 0,
        "issues": issues,
        "error": stderr if code == 2 else None,
    }


def run_trivy_image(image: str, severity: str = "HIGH,CRITICAL") -> dict[str, Any]:
    """Run trivy on a Docker image and return results."""
    cmd = ["trivy", "image", "--severity", severity, "--format", "json", image]

    code, stdout, stderr = run_command(cmd)

    try:
        results = json.loads(stdout) if stdout.strip() else {}
    except json.JSONDecodeError:
        results = {}

    vulnerabilities = []
    if "Results" in results:
        for result in results["Results"]:
            if "Vulnerabilities" in result:
                vulnerabilities.extend(result["Vulnerabilities"])

    return {
        "image": image,
        "passed": len(vulnerabilities) == 0,
        "vulnerability_count": len(vulnerabilities),
        "vulnerabilities": vulnerabilities[:10],  # Limit to first 10
        "error": stderr if code == 2 else None,
    }


def check_dockerfile_standards(dockerfile: Path) -> dict[str, Any]:
    """Check if Dockerfile follows A.R.C. constitution standards."""
    content = dockerfile.read_text()
    lines = content.split("\n")

    checks = {
        "has_user_instruction": False,
        "has_healthcheck": False,
        "has_labels": False,
        "uses_pinned_base": False,
        "uses_multi_stage": False,
        "no_latest_tag": True,
    }

    for line in lines:
        line_stripped = line.strip().upper()
        if line_stripped.startswith("USER ") and "ROOT" not in line_stripped:
            checks["has_user_instruction"] = True
        if line_stripped.startswith("HEALTHCHECK"):
            checks["has_healthcheck"] = True
        if line_stripped.startswith("LABEL"):
            checks["has_labels"] = True
        if line_stripped.startswith("FROM ") and " AS " in line_stripped:
            checks["uses_multi_stage"] = True
        if ":LATEST" in line_stripped:
            checks["no_latest_tag"] = False

    # Check for pinned versions in FROM
    for line in lines:
        if line.strip().upper().startswith("FROM "):
            if ":" in line and "@sha256:" not in line.lower():
                # Has a tag, check if it's not 'latest'
                if ":latest" not in line.lower():
                    checks["uses_pinned_base"] = True

    passed = all(checks.values())

    return {
        "file": str(dockerfile),
        "passed": passed,
        "checks": checks,
    }


def generate_report(repo_root: Path, output_file: Path | None = None) -> dict[str, Any]:
    """Generate comprehensive security report."""
    report = {
        "generated_at": datetime.now().isoformat(),
        "repository": str(repo_root),
        "summary": {
            "hadolint": {"passed": 0, "failed": 0, "total_issues": 0},
            "trivy": {"passed": 0, "failed": 0, "total_vulnerabilities": 0},
            "standards": {"passed": 0, "failed": 0},
        },
        "hadolint_results": [],
        "trivy_results": [],
        "standards_results": [],
        "recommendations": [],
    }

    # Find config file
    hadolint_config = repo_root / ".hadolint.yaml"

    # Run hadolint on all Dockerfiles
    print("🔍 Running hadolint on Dockerfiles...")
    dockerfiles = get_dockerfiles(repo_root)
    for dockerfile in dockerfiles:
        result = run_hadolint(dockerfile, hadolint_config)
        report["hadolint_results"].append(result)
        if result["passed"]:
            report["summary"]["hadolint"]["passed"] += 1
        else:
            report["summary"]["hadolint"]["failed"] += 1
            report["summary"]["hadolint"]["total_issues"] += len(result["issues"])

    # Run trivy on Docker images
    print("🔍 Running trivy on Docker images...")
    images = get_docker_images()
    for image in images:
        result = run_trivy_image(image)
        report["trivy_results"].append(result)
        if result["passed"]:
            report["summary"]["trivy"]["passed"] += 1
        else:
            report["summary"]["trivy"]["failed"] += 1
            report["summary"]["trivy"]["total_vulnerabilities"] += result[
                "vulnerability_count"
            ]

    # Check Dockerfile standards
    print("🔍 Checking A.R.C. Dockerfile standards...")
    for dockerfile in dockerfiles:
        result = check_dockerfile_standards(dockerfile)
        report["standards_results"].append(result)
        if result["passed"]:
            report["summary"]["standards"]["passed"] += 1
        else:
            report["summary"]["standards"]["failed"] += 1

    # Generate recommendations
    if report["summary"]["hadolint"]["failed"] > 0:
        report["recommendations"].append(
            "Fix hadolint violations: run `./scripts/validate/check-dockerfiles.sh` for details"
        )
    if report["summary"]["trivy"]["total_vulnerabilities"] > 0:
        report["recommendations"].append(
            "Update base images to fix vulnerabilities: check trivy output for CVE details"
        )
    if report["summary"]["standards"]["failed"] > 0:
        report["recommendations"].append(
            "Ensure all Dockerfiles have: USER (non-root), HEALTHCHECK, LABEL, pinned base images"
        )

    return report


def print_markdown_report(report: dict[str, Any]) -> None:
    """Print report in Markdown format."""
    print("\n# A.R.C. Security Compliance Report")
    print(f"\n**Generated:** {report['generated_at']}")
    print(f"**Repository:** {report['repository']}")

    print("\n## Summary")
    print("\n| Check | Passed | Failed | Issues |")
    print("|-------|--------|--------|--------|")
    print(
        f"| Hadolint | {report['summary']['hadolint']['passed']} | {report['summary']['hadolint']['failed']} | {report['summary']['hadolint']['total_issues']} |"
    )
    print(
        f"| Trivy | {report['summary']['trivy']['passed']} | {report['summary']['trivy']['failed']} | {report['summary']['trivy']['total_vulnerabilities']} |"
    )
    print(
        f"| Standards | {report['summary']['standards']['passed']} | {report['summary']['standards']['failed']} | - |"
    )

    if report["recommendations"]:
        print("\n## Recommendations")
        for rec in report["recommendations"]:
            print(f"- {rec}")

    # Hadolint details
    failed_hadolint = [r for r in report["hadolint_results"] if not r["passed"]]
    if failed_hadolint:
        print("\n## Hadolint Violations")
        for result in failed_hadolint:
            print(f"\n### {result['file']}")
            for issue in result["issues"][:5]:
                print(f"- **{issue.get('code', 'N/A')}**: {issue.get('message', 'N/A')}")

    # Standards details
    failed_standards = [r for r in report["standards_results"] if not r["passed"]]
    if failed_standards:
        print("\n## Standards Violations")
        for result in failed_standards:
            print(f"\n### {result['file']}")
            for check, passed in result["checks"].items():
                status = "✅" if passed else "❌"
                print(f"- {status} {check.replace('_', ' ').title()}")

    # Overall status
    total_failed = (
        report["summary"]["hadolint"]["failed"]
        + report["summary"]["trivy"]["failed"]
        + report["summary"]["standards"]["failed"]
    )
    print("\n## Status")
    if total_failed == 0:
        print("\n✅ **All security checks passed**")
    else:
        print(f"\n❌ **{total_failed} checks failed** - see recommendations above")


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Generate A.R.C. security compliance report"
    )
    parser.add_argument(
        "--output", "-o", type=Path, help="Output file for JSON report"
    )
    parser.add_argument(
        "--json", action="store_true", help="Output JSON instead of Markdown"
    )
    args = parser.parse_args()

    # Find repository root
    script_path = Path(__file__).resolve()
    repo_root = script_path.parent.parent.parent

    # Generate report
    report = generate_report(repo_root, args.output)

    # Output
    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print_markdown_report(report)

    # Save to file if requested
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2))
        print(f"\n📄 Report saved to: {args.output}")

    # Exit code
    total_failed = (
        report["summary"]["hadolint"]["failed"]
        + report["summary"]["trivy"]["failed"]
        + report["summary"]["standards"]["failed"]
    )
    return 1 if total_failed > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
