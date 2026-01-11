#!/usr/bin/env python3
"""
Generate comprehensive dependency reports from SBOM data.

Creates various report formats for different stakeholders:
- Executive summary for leadership
- Detailed report for security team
- Compliance export for auditors
- Markdown for PR comments

Usage:
    python generate-dependency-report.py --sbom report.json --format markdown
    python generate-dependency-report.py --sbom report.json --format html --output report.html
    python generate-dependency-report.py --sbom report.json --vulns vulns.json --format executive

Output formats:
    markdown: GitHub-flavored markdown
    html: Standalone HTML report
    json: Structured JSON data
    csv: Spreadsheet-compatible CSV
    executive: Brief summary for leadership
"""
import argparse
import csv
import json
import logging
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Optional

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)


@dataclass
class ReportData:
    """Aggregated report data."""
    generated_at: str
    total_dependencies: int
    unique_packages: int
    services: list[str]
    by_service: dict
    by_type: dict
    by_license: dict
    vulnerabilities: dict
    outdated: list
    high_risk: list


def load_sbom_data(sbom_path: Path) -> dict:
    """Load SBOM data from JSON or CSV."""
    if sbom_path.suffix == '.json':
        with open(sbom_path) as f:
            return json.load(f)
    elif sbom_path.suffix == '.csv':
        deps = []
        with open(sbom_path, newline='') as f:
            reader = csv.DictReader(f)
            for row in reader:
                deps.append(row)
        return {
            'dependencies': deps,
            'total_dependencies': len(deps),
            'services': list(set(d.get('service', 'unknown') for d in deps)),
        }
    else:
        raise ValueError(f"Unsupported format: {sbom_path.suffix}")


def load_vulnerability_data(vulns_path: Optional[Path]) -> list[dict]:
    """Load vulnerability data from Trivy JSON report."""
    if not vulns_path or not vulns_path.exists():
        return []

    with open(vulns_path) as f:
        data = json.load(f)

    vulns = []
    for result in data.get('Results', []):
        for vuln in result.get('Vulnerabilities', []):
            vulns.append({
                'cve_id': vuln.get('VulnerabilityID', 'Unknown'),
                'severity': vuln.get('Severity', 'UNKNOWN'),
                'package': vuln.get('PkgName', 'Unknown'),
                'installed_version': vuln.get('InstalledVersion', 'Unknown'),
                'fixed_version': vuln.get('FixedVersion'),
            })

    return vulns


def aggregate_data(sbom_data: dict, vulns: list[dict]) -> ReportData:
    """Aggregate SBOM and vulnerability data."""
    deps = sbom_data.get('dependencies', [])

    # Aggregate by service
    by_service = defaultdict(list)
    for dep in deps:
        service = dep.get('service', 'unknown')
        by_service[service].append(dep)

    # Aggregate by type
    by_type = defaultdict(int)
    for dep in deps:
        pkg_type = dep.get('type', 'unknown')
        by_type[pkg_type] += 1

    # Aggregate by license
    by_license = defaultdict(int)
    for dep in deps:
        license_info = dep.get('license', 'Unknown')
        by_license[license_info] += 1

    # Vulnerability summary
    vuln_summary = {
        'total': len(vulns),
        'critical': sum(1 for v in vulns if v['severity'] == 'CRITICAL'),
        'high': sum(1 for v in vulns if v['severity'] == 'HIGH'),
        'medium': sum(1 for v in vulns if v['severity'] == 'MEDIUM'),
        'low': sum(1 for v in vulns if v['severity'] == 'LOW'),
        'with_fix': sum(1 for v in vulns if v.get('fixed_version')),
        'details': vulns[:50],  # Top 50 for report
    }

    # High-risk packages (multiple vulnerabilities or critical)
    pkg_vuln_count = defaultdict(list)
    for v in vulns:
        pkg_vuln_count[v['package']].append(v)

    high_risk = [
        {'package': pkg, 'vuln_count': len(vs), 'critical': sum(1 for v in vs if v['severity'] == 'CRITICAL')}
        for pkg, vs in pkg_vuln_count.items()
        if len(vs) > 1 or any(v['severity'] == 'CRITICAL' for v in vs)
    ]
    high_risk.sort(key=lambda x: (-x['critical'], -x['vuln_count']))

    return ReportData(
        generated_at=datetime.utcnow().isoformat(),
        total_dependencies=len(deps),
        unique_packages=len(set(d.get('package', '') for d in deps)),
        services=list(by_service.keys()),
        by_service={k: len(v) for k, v in by_service.items()},
        by_type=dict(by_type),
        by_license=dict(sorted(by_license.items(), key=lambda x: -x[1])[:20]),
        vulnerabilities=vuln_summary,
        outdated=[],  # Would require version comparison logic
        high_risk=high_risk[:10],
    )


def generate_markdown_report(data: ReportData) -> str:
    """Generate GitHub-flavored markdown report."""
    lines = [
        "# Dependency Report",
        "",
        f"**Generated:** {data.generated_at}",
        "",
        "## Summary",
        "",
        "| Metric | Value |",
        "|--------|-------|",
        f"| Total Dependencies | {data.total_dependencies} |",
        f"| Unique Packages | {data.unique_packages} |",
        f"| Services | {len(data.services)} |",
        "",
        "## Vulnerabilities",
        "",
    ]

    vuln = data.vulnerabilities
    if vuln['total'] > 0:
        lines.extend([
            "| Severity | Count |",
            "|----------|-------|",
            f"| 🔴 CRITICAL | {vuln['critical']} |",
            f"| 🟠 HIGH | {vuln['high']} |",
            f"| 🟡 MEDIUM | {vuln['medium']} |",
            f"| 🟢 LOW | {vuln['low']} |",
            "",
            f"**With available fix:** {vuln['with_fix']} ({vuln['with_fix']*100//max(vuln['total'],1)}%)",
            "",
        ])

        if data.high_risk:
            lines.extend([
                "### High-Risk Packages",
                "",
                "| Package | Vulnerabilities | Critical |",
                "|---------|-----------------|----------|",
            ])
            for pkg in data.high_risk[:5]:
                lines.append(f"| {pkg['package']} | {pkg['vuln_count']} | {pkg['critical']} |")
            lines.append("")
    else:
        lines.extend([
            "✅ No vulnerabilities detected",
            "",
        ])

    # Dependencies by service
    lines.extend([
        "## Dependencies by Service",
        "",
        "| Service | Count |",
        "|---------|-------|",
    ])
    for service, count in sorted(data.by_service.items(), key=lambda x: -x[1]):
        lines.append(f"| {service} | {count} |")

    lines.append("")

    # Dependencies by type
    lines.extend([
        "## Dependencies by Type",
        "",
        "| Type | Count |",
        "|------|-------|",
    ])
    for pkg_type, count in sorted(data.by_type.items(), key=lambda x: -x[1]):
        lines.append(f"| {pkg_type} | {count} |")

    lines.append("")

    # Top licenses
    lines.extend([
        "## Top Licenses",
        "",
        "| License | Count |",
        "|---------|-------|",
    ])
    for license_name, count in list(data.by_license.items())[:10]:
        lines.append(f"| {license_name} | {count} |")

    lines.extend([
        "",
        "---",
        "",
        "_Generated by A.R.C. Dependency Report Generator_",
    ])

    return "\n".join(lines)


def generate_html_report(data: ReportData) -> str:
    """Generate standalone HTML report."""
    vuln = data.vulnerabilities

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>A.R.C. Dependency Report</title>
    <style>
        :root {{
            --primary: #2563eb;
            --danger: #dc2626;
            --warning: #f59e0b;
            --success: #10b981;
            --gray-50: #f9fafb;
            --gray-100: #f3f4f6;
            --gray-200: #e5e7eb;
            --gray-700: #374151;
            --gray-900: #111827;
        }}
        * {{ box-sizing: border-box; margin: 0; padding: 0; }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: var(--gray-50);
            color: var(--gray-900);
            line-height: 1.6;
        }}
        .container {{ max-width: 1200px; margin: 0 auto; padding: 2rem; }}
        header {{
            background: var(--primary);
            color: white;
            padding: 2rem;
            margin-bottom: 2rem;
            border-radius: 0.5rem;
        }}
        header h1 {{ font-size: 1.75rem; margin-bottom: 0.5rem; }}
        header p {{ opacity: 0.9; }}
        .grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 1rem; margin-bottom: 2rem; }}
        .card {{
            background: white;
            border-radius: 0.5rem;
            padding: 1.5rem;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }}
        .card h3 {{ font-size: 0.875rem; color: var(--gray-700); margin-bottom: 0.5rem; }}
        .card .value {{ font-size: 2rem; font-weight: bold; }}
        .card.danger {{ border-left: 4px solid var(--danger); }}
        .card.warning {{ border-left: 4px solid var(--warning); }}
        .card.success {{ border-left: 4px solid var(--success); }}
        table {{
            width: 100%;
            border-collapse: collapse;
            background: white;
            border-radius: 0.5rem;
            overflow: hidden;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
            margin-bottom: 2rem;
        }}
        th, td {{ padding: 0.75rem 1rem; text-align: left; border-bottom: 1px solid var(--gray-200); }}
        th {{ background: var(--gray-100); font-weight: 600; }}
        tr:hover {{ background: var(--gray-50); }}
        .badge {{
            display: inline-block;
            padding: 0.25rem 0.5rem;
            border-radius: 9999px;
            font-size: 0.75rem;
            font-weight: 500;
        }}
        .badge-critical {{ background: #fee2e2; color: #991b1b; }}
        .badge-high {{ background: #ffedd5; color: #9a3412; }}
        .badge-medium {{ background: #fef3c7; color: #92400e; }}
        .badge-low {{ background: #d1fae5; color: #065f46; }}
        footer {{ text-align: center; color: var(--gray-700); padding: 2rem; }}
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>🔒 A.R.C. Dependency Report</h1>
            <p>Generated: {data.generated_at}</p>
        </header>

        <div class="grid">
            <div class="card">
                <h3>Total Dependencies</h3>
                <div class="value">{data.total_dependencies}</div>
            </div>
            <div class="card">
                <h3>Unique Packages</h3>
                <div class="value">{data.unique_packages}</div>
            </div>
            <div class="card">
                <h3>Services Tracked</h3>
                <div class="value">{len(data.services)}</div>
            </div>
            <div class="card {'danger' if vuln['critical'] > 0 else 'warning' if vuln['high'] > 0 else 'success'}">
                <h3>Vulnerabilities</h3>
                <div class="value">{vuln['total']}</div>
            </div>
        </div>

        <h2>Vulnerability Summary</h2>
        <table>
            <thead>
                <tr><th>Severity</th><th>Count</th><th>With Fix Available</th></tr>
            </thead>
            <tbody>
                <tr>
                    <td><span class="badge badge-critical">CRITICAL</span></td>
                    <td>{vuln['critical']}</td>
                    <td>-</td>
                </tr>
                <tr>
                    <td><span class="badge badge-high">HIGH</span></td>
                    <td>{vuln['high']}</td>
                    <td>-</td>
                </tr>
                <tr>
                    <td><span class="badge badge-medium">MEDIUM</span></td>
                    <td>{vuln['medium']}</td>
                    <td>-</td>
                </tr>
                <tr>
                    <td><span class="badge badge-low">LOW</span></td>
                    <td>{vuln['low']}</td>
                    <td>-</td>
                </tr>
            </tbody>
        </table>

        <h2>Dependencies by Service</h2>
        <table>
            <thead>
                <tr><th>Service</th><th>Dependencies</th></tr>
            </thead>
            <tbody>
                {''.join(f'<tr><td>{s}</td><td>{c}</td></tr>' for s, c in sorted(data.by_service.items(), key=lambda x: -x[1]))}
            </tbody>
        </table>

        <h2>Top Licenses</h2>
        <table>
            <thead>
                <tr><th>License</th><th>Count</th></tr>
            </thead>
            <tbody>
                {''.join(f'<tr><td>{l}</td><td>{c}</td></tr>' for l, c in list(data.by_license.items())[:10])}
            </tbody>
        </table>

        <footer>
            <p>A.R.C. Platform - Dependency Report Generator</p>
        </footer>
    </div>
</body>
</html>"""

    return html


def generate_executive_report(data: ReportData) -> str:
    """Generate brief executive summary."""
    vuln = data.vulnerabilities

    # Risk level
    if vuln['critical'] > 0:
        risk_level = "🔴 HIGH RISK"
        risk_action = "Immediate action required"
    elif vuln['high'] > 0:
        risk_level = "🟠 ELEVATED"
        risk_action = "Action recommended within 7 days"
    elif vuln['total'] > 0:
        risk_level = "🟡 MODERATE"
        risk_action = "Review during next sprint"
    else:
        risk_level = "🟢 LOW"
        risk_action = "No immediate action required"

    lines = [
        "# Executive Summary: Dependency Security",
        "",
        f"**Report Date:** {data.generated_at[:10]}",
        f"**Risk Level:** {risk_level}",
        f"**Recommended Action:** {risk_action}",
        "",
        "## Key Metrics",
        "",
        f"- **{data.total_dependencies}** total dependencies across **{len(data.services)}** services",
        f"- **{vuln['critical']}** critical vulnerabilities requiring immediate attention",
        f"- **{vuln['high']}** high-severity vulnerabilities",
        f"- **{vuln['with_fix']}** vulnerabilities have available fixes",
        "",
    ]

    if data.high_risk:
        lines.extend([
            "## Priority Packages",
            "",
            "The following packages have the highest risk and should be addressed first:",
            "",
        ])
        for i, pkg in enumerate(data.high_risk[:3], 1):
            lines.append(f"{i}. **{pkg['package']}** - {pkg['vuln_count']} vulnerabilities ({pkg['critical']} critical)")
        lines.append("")

    lines.extend([
        "## Recommendations",
        "",
        "1. Address all CRITICAL vulnerabilities within 24-48 hours",
        "2. Plan HIGH vulnerabilities for current sprint",
        "3. Review dependency update strategy quarterly",
        "",
        "---",
        "",
        "_Contact security team for detailed remediation guidance._",
    ])

    return "\n".join(lines)


def generate_json_report(data: ReportData) -> str:
    """Generate JSON report."""
    return json.dumps({
        'generated_at': data.generated_at,
        'summary': {
            'total_dependencies': data.total_dependencies,
            'unique_packages': data.unique_packages,
            'services': data.services,
        },
        'by_service': data.by_service,
        'by_type': data.by_type,
        'by_license': data.by_license,
        'vulnerabilities': data.vulnerabilities,
        'high_risk_packages': data.high_risk,
    }, indent=2)


def generate_csv_report(data: ReportData, sbom_data: dict) -> str:
    """Generate CSV report with all dependencies."""
    import io
    output = io.StringIO()
    writer = csv.writer(output)

    # Header
    writer.writerow([
        'Service', 'Package', 'Version', 'Type', 'License', 'PURL', 'Supplier'
    ])

    # Data
    for dep in sbom_data.get('dependencies', []):
        writer.writerow([
            dep.get('service', ''),
            dep.get('package', ''),
            dep.get('version', ''),
            dep.get('type', ''),
            dep.get('license', ''),
            dep.get('purl', ''),
            dep.get('supplier', ''),
        ])

    return output.getvalue()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        '--sbom',
        type=Path,
        required=True,
        help='Path to SBOM file (JSON or CSV)',
    )
    parser.add_argument(
        '--vulns',
        type=Path,
        default=None,
        help='Path to Trivy vulnerability report (JSON)',
    )
    parser.add_argument(
        '--format',
        choices=['markdown', 'html', 'json', 'csv', 'executive'],
        default='markdown',
        help='Output format',
    )
    parser.add_argument(
        '--output',
        type=Path,
        default=None,
        help='Output file (default: stdout)',
    )

    args = parser.parse_args()

    # Load data
    logger.info(f"Loading SBOM: {args.sbom}")
    sbom_data = load_sbom_data(args.sbom)

    vulns = []
    if args.vulns:
        logger.info(f"Loading vulnerabilities: {args.vulns}")
        vulns = load_vulnerability_data(args.vulns)

    # Aggregate
    data = aggregate_data(sbom_data, vulns)

    # Generate report
    if args.format == 'markdown':
        report = generate_markdown_report(data)
    elif args.format == 'html':
        report = generate_html_report(data)
    elif args.format == 'executive':
        report = generate_executive_report(data)
    elif args.format == 'json':
        report = generate_json_report(data)
    elif args.format == 'csv':
        report = generate_csv_report(data, sbom_data)
    else:
        raise ValueError(f"Unknown format: {args.format}")

    # Output
    if args.output:
        with open(args.output, 'w') as f:
            f.write(report)
        logger.info(f"Report written to: {args.output}")
    else:
        print(report)


if __name__ == '__main__':
    main()
