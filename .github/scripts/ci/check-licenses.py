#!/usr/bin/env python3
"""
Check software licenses against organization policy.

Validates dependencies from SBOM files against an allow/deny list policy,
identifying packages with problematic licenses that need review.

Usage:
    python check-licenses.py --sbom report.csv --policy license-policy.json
    python check-licenses.py --sbom report.csv --policy license-policy.json --strict

Exit codes:
    0: All licenses compliant
    1: Denied licenses found
    2: Unknown licenses found (only with --strict)
"""
import argparse
import csv
import json
import logging
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)


@dataclass
class LicensePolicy:
    """Organization license policy."""
    allowed: list[str]
    denied: list[str]
    exceptions: dict[str, str]  # package -> reason
    unknown_action: str  # 'allow', 'deny', 'warn'

    @classmethod
    def from_file(cls, path: Path) -> 'LicensePolicy':
        """Load policy from JSON file."""
        with open(path) as f:
            data = json.load(f)

        return cls(
            allowed=data.get('allowed_licenses', []),
            denied=data.get('denied_licenses', []),
            exceptions=data.get('exceptions', {}),
            unknown_action=data.get('unknown_action', 'warn'),
        )


@dataclass
class LicenseViolation:
    """Represents a license policy violation."""
    package: str
    version: str
    license: str
    service: str
    violation_type: str  # 'denied', 'unknown'
    reason: Optional[str] = None


def normalize_license(license_str: str) -> str:
    """Normalize license string for comparison."""
    if not license_str:
        return 'unknown'

    # Convert to uppercase for comparison
    normalized = license_str.upper().strip()

    # Common normalizations
    normalizations = {
        'APACHE 2.0': 'APACHE-2.0',
        'APACHE LICENSE 2.0': 'APACHE-2.0',
        'APACHE LICENSE, VERSION 2.0': 'APACHE-2.0',
        'APACHE-2': 'APACHE-2.0',
        'MIT LICENSE': 'MIT',
        'MIT/X11': 'MIT',
        'BSD 2-CLAUSE': 'BSD-2-CLAUSE',
        'BSD 3-CLAUSE': 'BSD-3-CLAUSE',
        'BSD-2': 'BSD-2-CLAUSE',
        'BSD-3': 'BSD-3-CLAUSE',
        'BSD': 'BSD-3-CLAUSE',
        'GPL-2': 'GPL-2.0',
        'GPL-3': 'GPL-3.0',
        'GPLV2': 'GPL-2.0',
        'GPLV3': 'GPL-3.0',
        'LGPL-2': 'LGPL-2.0',
        'LGPL-3': 'LGPL-3.0',
        'LGPLV2': 'LGPL-2.0',
        'LGPLV3': 'LGPL-3.0',
        'MOZILLA PUBLIC LICENSE 2.0': 'MPL-2.0',
        'ISC LICENSE': 'ISC',
        'PYTHON SOFTWARE FOUNDATION LICENSE': 'PSF-2.0',
        'PYTHON-2.0': 'PSF-2.0',
        'NOASSERTION': 'UNKNOWN',
        'NONE': 'UNKNOWN',
        '': 'UNKNOWN',
    }

    return normalizations.get(normalized, normalized)


def check_license(
    license_str: str,
    package: str,
    policy: LicensePolicy,
) -> tuple[bool, str]:
    """
    Check if a license is compliant with policy.

    Returns:
        Tuple of (is_compliant, violation_type or 'ok')
    """
    # Check exceptions first
    if package.lower() in [p.lower() for p in policy.exceptions.keys()]:
        return True, 'exception'

    normalized = normalize_license(license_str)

    # Check denied list
    for denied in policy.denied:
        if normalized == denied.upper() or denied.upper() in normalized:
            return False, 'denied'

    # Check allowed list
    for allowed in policy.allowed:
        if normalized == allowed.upper() or allowed.upper() in normalized:
            return True, 'allowed'

    # Handle unknown licenses
    if normalized == 'UNKNOWN' or 'UNKNOWN' in normalized:
        if policy.unknown_action == 'allow':
            return True, 'unknown-allowed'
        elif policy.unknown_action == 'deny':
            return False, 'unknown'
        else:
            return True, 'unknown-warn'

    # License not in any list
    if policy.unknown_action == 'deny':
        return False, 'unknown'
    else:
        return True, 'unknown-warn'


def load_dependencies(sbom_path: Path) -> list[dict]:
    """Load dependencies from SBOM CSV or JSON file."""
    dependencies = []

    if sbom_path.suffix == '.json':
        with open(sbom_path) as f:
            data = json.load(f)
            return data.get('dependencies', [])

    elif sbom_path.suffix == '.csv':
        with open(sbom_path, newline='') as f:
            reader = csv.DictReader(f)
            for row in reader:
                dependencies.append(row)
        return dependencies

    else:
        raise ValueError(f"Unsupported file format: {sbom_path.suffix}")


def check_licenses(
    dependencies: list[dict],
    policy: LicensePolicy,
    strict: bool = False,
) -> list[LicenseViolation]:
    """Check all dependencies against license policy."""
    violations = []
    warnings = []

    for dep in dependencies:
        package = dep.get('package', 'unknown')
        version = dep.get('version', 'unknown')
        license_str = dep.get('license', 'unknown')
        service = dep.get('service', 'unknown')

        is_compliant, result = check_license(license_str, package, policy)

        if not is_compliant:
            violation = LicenseViolation(
                package=package,
                version=version,
                license=license_str,
                service=service,
                violation_type=result,
            )
            violations.append(violation)

        elif result == 'unknown-warn':
            warning = LicenseViolation(
                package=package,
                version=version,
                license=license_str,
                service=service,
                violation_type='warning',
            )
            warnings.append(warning)

    # In strict mode, treat warnings as violations
    if strict:
        violations.extend(warnings)

    return violations


def generate_report(
    violations: list[LicenseViolation],
    output_format: str = 'text',
) -> str:
    """Generate violation report."""
    if not violations:
        if output_format == 'json':
            return json.dumps({'status': 'compliant', 'violations': []})
        return "All licenses are compliant with policy."

    if output_format == 'json':
        return json.dumps({
            'status': 'non-compliant',
            'violation_count': len(violations),
            'violations': [
                {
                    'package': v.package,
                    'version': v.version,
                    'license': v.license,
                    'service': v.service,
                    'type': v.violation_type,
                }
                for v in violations
            ],
        }, indent=2)

    # Text format
    lines = [
        "License Policy Violations",
        "=" * 50,
        "",
    ]

    # Group by violation type
    denied = [v for v in violations if v.violation_type == 'denied']
    unknown = [v for v in violations if v.violation_type in ('unknown', 'warning')]

    if denied:
        lines.append(f"DENIED LICENSES ({len(denied)}):")
        lines.append("-" * 30)
        for v in denied:
            lines.append(f"  ❌ {v.package}@{v.version}")
            lines.append(f"     License: {v.license}")
            lines.append(f"     Service: {v.service}")
            lines.append("")

    if unknown:
        lines.append(f"UNKNOWN LICENSES ({len(unknown)}):")
        lines.append("-" * 30)
        for v in unknown:
            lines.append(f"  ⚠️  {v.package}@{v.version}")
            lines.append(f"     License: {v.license}")
            lines.append(f"     Service: {v.service}")
            lines.append("")

    lines.extend([
        "=" * 50,
        f"Total violations: {len(violations)}",
        "",
        "To resolve:",
        "  1. Add package to exceptions with justification",
        "  2. Replace package with an alternative",
        "  3. Update license-policy.json if license should be allowed",
    ])

    return "\n".join(lines)


def generate_github_summary(violations: list[LicenseViolation]) -> str:
    """Generate GitHub Actions step summary."""
    lines = [
        "## License Compliance Check",
        "",
    ]

    if not violations:
        lines.extend([
            "### ✅ All Licenses Compliant",
            "",
            "All dependencies use approved licenses.",
        ])
        return "\n".join(lines)

    denied = [v for v in violations if v.violation_type == 'denied']
    unknown = [v for v in violations if v.violation_type in ('unknown', 'warning')]

    lines.extend([
        f"### ❌ {len(violations)} License Violation(s) Found",
        "",
        "| Package | Version | License | Service | Status |",
        "|---------|---------|---------|---------|--------|",
    ])

    for v in denied:
        lines.append(f"| {v.package} | {v.version} | {v.license} | {v.service} | 🚫 Denied |")

    for v in unknown:
        lines.append(f"| {v.package} | {v.version} | {v.license} | {v.service} | ⚠️ Unknown |")

    lines.extend([
        "",
        "### Resolution Steps",
        "",
        "1. **Add Exception**: If the license is acceptable for this package, add to `exceptions` in `license-policy.json`",
        "2. **Replace Package**: Find an alternative with an approved license",
        "3. **Update Policy**: If the license should be globally allowed, add to `allowed_licenses`",
    ])

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        '--sbom',
        type=Path,
        required=True,
        help='Path to SBOM file (CSV or JSON from consolidate-sbom.py)',
    )
    parser.add_argument(
        '--policy',
        type=Path,
        required=True,
        help='Path to license policy JSON file',
    )
    parser.add_argument(
        '--strict',
        action='store_true',
        help='Treat unknown licenses as violations',
    )
    parser.add_argument(
        '--format',
        choices=['text', 'json', 'github'],
        default='text',
        help='Output format',
    )
    parser.add_argument(
        '--output',
        type=Path,
        default=None,
        help='Output file (default: stdout)',
    )

    args = parser.parse_args()

    # Validate inputs
    if not args.sbom.exists():
        logger.error(f"SBOM file not found: {args.sbom}")
        sys.exit(1)

    if not args.policy.exists():
        logger.error(f"Policy file not found: {args.policy}")
        sys.exit(1)

    # Load policy
    logger.info(f"Loading policy: {args.policy}")
    policy = LicensePolicy.from_file(args.policy)
    logger.info(f"  Allowed licenses: {len(policy.allowed)}")
    logger.info(f"  Denied licenses: {len(policy.denied)}")
    logger.info(f"  Exceptions: {len(policy.exceptions)}")

    # Load dependencies
    logger.info(f"Loading SBOM: {args.sbom}")
    dependencies = load_dependencies(args.sbom)
    logger.info(f"  Dependencies: {len(dependencies)}")

    # Check licenses
    violations = check_licenses(dependencies, policy, args.strict)
    logger.info(f"  Violations: {len(violations)}")

    # Generate report
    if args.format == 'github':
        report = generate_github_summary(violations)
    else:
        report = generate_report(violations, args.format)

    # Output
    if args.output:
        with open(args.output, 'w') as f:
            f.write(report)
        logger.info(f"Report written to: {args.output}")
    else:
        print(report)

    # Exit code
    denied_violations = [v for v in violations if v.violation_type == 'denied']
    if denied_violations:
        sys.exit(1)

    unknown_violations = [v for v in violations if v.violation_type in ('unknown', 'warning')]
    if args.strict and unknown_violations:
        sys.exit(2)

    sys.exit(0)


if __name__ == '__main__':
    main()
