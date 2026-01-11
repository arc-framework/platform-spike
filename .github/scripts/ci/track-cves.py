#!/usr/bin/env python3
"""
Track CVEs across GitHub Issues to prevent duplicates.

Maintains CVE tracking state and provides utilities for:
- Checking if a CVE issue already exists
- Creating new issues with proper labels
- Closing issues when CVEs are resolved
- Generating CVE inventory reports

Usage:
    python track-cves.py check --cve CVE-2024-1234 --service brain
    python track-cves.py create --trivy-report results.json --service brain
    python track-cves.py report --output cve-inventory.json

Environment Variables:
    GITHUB_TOKEN: GitHub token with issues permission
    GITHUB_REPOSITORY: Repository in owner/repo format
"""
import argparse
import json
import logging
import os
import sys
from dataclasses import dataclass, asdict
from datetime import datetime
from typing import Optional

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)

# Labels used for CVE tracking
CVE_LABELS = ['security', 'cve', 'cve-tracked']
SEVERITY_LABELS = {
    'CRITICAL': 'critical',
    'HIGH': 'high',
    'MEDIUM': 'medium',
    'LOW': 'low',
}


@dataclass
class TrackedCVE:
    """Represents a tracked CVE."""
    cve_id: str
    service: str
    severity: str
    package: str
    installed_version: str
    fixed_version: Optional[str]
    issue_number: Optional[int]
    issue_url: Optional[str]
    created_at: Optional[str]
    resolved_at: Optional[str]
    status: str  # 'open', 'resolved', 'wontfix'


def get_github_client():
    """Get authenticated GitHub client."""
    try:
        from github import Github
        token = os.environ.get('GITHUB_TOKEN')
        if not token:
            raise ValueError("GITHUB_TOKEN environment variable required")
        return Github(token)
    except ImportError:
        logger.error("PyGithub not installed. Run: pip install PyGithub")
        sys.exit(1)


def get_repo():
    """Get repository object."""
    g = get_github_client()
    repo_name = os.environ.get('GITHUB_REPOSITORY')
    if not repo_name:
        raise ValueError("GITHUB_REPOSITORY environment variable required")
    return g.get_repo(repo_name)


def search_existing_issues(
    cve_id: str,
    service: Optional[str] = None,
) -> list[dict]:
    """Search for existing CVE issues."""
    repo = get_repo()

    # Build search query
    labels = CVE_LABELS.copy()

    # Get all open issues with CVE labels
    issues = repo.get_issues(state='open', labels=labels)

    matches = []
    for issue in issues:
        # Check if CVE ID is in title or body
        if cve_id.upper() in issue.title.upper() or cve_id.upper() in (issue.body or '').upper():
            # If service specified, also check service matches
            if service:
                if service.lower() in issue.title.lower() or service.lower() in (issue.body or '').lower():
                    matches.append({
                        'number': issue.number,
                        'title': issue.title,
                        'url': issue.html_url,
                        'state': issue.state,
                        'created_at': issue.created_at.isoformat(),
                    })
            else:
                matches.append({
                    'number': issue.number,
                    'title': issue.title,
                    'url': issue.html_url,
                    'state': issue.state,
                    'created_at': issue.created_at.isoformat(),
                })

    return matches


def parse_trivy_cves(report_path: str) -> list[dict]:
    """Parse CVEs from Trivy JSON report."""
    with open(report_path) as f:
        data = json.load(f)

    cves = []
    for result in data.get('Results', []):
        for vuln in result.get('Vulnerabilities', []):
            cves.append({
                'cve_id': vuln.get('VulnerabilityID', 'Unknown'),
                'severity': vuln.get('Severity', 'UNKNOWN'),
                'package': vuln.get('PkgName', 'Unknown'),
                'installed_version': vuln.get('InstalledVersion', 'Unknown'),
                'fixed_version': vuln.get('FixedVersion'),
                'title': vuln.get('Title', 'No title'),
                'description': vuln.get('Description', '')[:500],
            })

    return cves


def check_cve(cve_id: str, service: Optional[str] = None) -> dict:
    """Check if a CVE is already tracked."""
    matches = search_existing_issues(cve_id, service)

    return {
        'cve_id': cve_id,
        'service': service,
        'is_tracked': len(matches) > 0,
        'existing_issues': matches,
    }


def create_cve_issues(
    trivy_report: str,
    service: str,
    min_severity: str = 'CRITICAL',
    dry_run: bool = False,
) -> list[dict]:
    """Create GitHub issues for new CVEs."""
    severity_order = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW']
    min_index = severity_order.index(min_severity)
    included_severities = severity_order[:min_index + 1]

    cves = parse_trivy_cves(trivy_report)
    cves = [c for c in cves if c['severity'] in included_severities]

    if not cves:
        logger.info("No CVEs at or above minimum severity")
        return []

    created_issues = []
    skipped_issues = []

    repo = None if dry_run else get_repo()

    for cve in cves:
        cve_id = cve['cve_id']

        # Check if already tracked
        existing = search_existing_issues(cve_id, service) if not dry_run else []
        if existing:
            skipped_issues.append({
                'cve_id': cve_id,
                'reason': 'already_tracked',
                'existing_issue': existing[0],
            })
            continue

        # Create issue
        title = f"🔴 {cve['severity']}: {cve_id} in {service} ({cve['package']})"

        body = f"""## Security Vulnerability

**CVE:** {cve_id}
**Severity:** {cve['severity']}
**Service:** `{service}`
**Package:** `{cve['package']}`
**Installed Version:** `{cve['installed_version']}`
**Fixed Version:** `{cve['fixed_version'] or 'No fix available'}`

### Description

{cve['title']}

{cve['description']}

### Resolution

1. Update `{cve['package']}` to version `{cve['fixed_version'] or 'a fixed version when available'}`
2. Rebuild and redeploy the `{service}` service
3. Verify the vulnerability is resolved with a new scan

### References

- [NVD Entry](https://nvd.nist.gov/vuln/detail/{cve_id})
- [MITRE CVE](https://cve.mitre.org/cgi-bin/cvename.cgi?name={cve_id})

---

_This issue was automatically created by A.R.C. CVE tracking._
_Detected: {datetime.utcnow().strftime('%Y-%m-%d %H:%M UTC')}_
"""

        labels = CVE_LABELS + [SEVERITY_LABELS.get(cve['severity'], 'unknown'), 'automated']

        if dry_run:
            logger.info(f"DRY RUN: Would create issue for {cve_id}")
            created_issues.append({
                'cve_id': cve_id,
                'title': title,
                'labels': labels,
                'dry_run': True,
            })
        else:
            try:
                issue = repo.create_issue(
                    title=title,
                    body=body,
                    labels=labels,
                )
                created_issues.append({
                    'cve_id': cve_id,
                    'issue_number': issue.number,
                    'issue_url': issue.html_url,
                })
                logger.info(f"Created issue #{issue.number} for {cve_id}")
            except Exception as e:
                logger.error(f"Failed to create issue for {cve_id}: {e}")

    return {
        'created': created_issues,
        'skipped': skipped_issues,
        'total_cves': len(cves),
    }


def generate_report(output_path: Optional[str] = None) -> dict:
    """Generate CVE inventory report."""
    repo = get_repo()

    # Get all CVE issues
    issues = repo.get_issues(state='all', labels=CVE_LABELS)

    inventory = {
        'generated_at': datetime.utcnow().isoformat(),
        'repository': os.environ.get('GITHUB_REPOSITORY'),
        'summary': {
            'total': 0,
            'open': 0,
            'closed': 0,
            'by_severity': {},
        },
        'issues': [],
    }

    for issue in issues:
        # Extract severity from labels
        severity = 'unknown'
        for label in issue.labels:
            if label.name in SEVERITY_LABELS.values():
                severity = label.name
                break

        issue_data = {
            'number': issue.number,
            'title': issue.title,
            'url': issue.html_url,
            'state': issue.state,
            'severity': severity,
            'created_at': issue.created_at.isoformat(),
            'closed_at': issue.closed_at.isoformat() if issue.closed_at else None,
            'labels': [l.name for l in issue.labels],
        }

        inventory['issues'].append(issue_data)
        inventory['summary']['total'] += 1

        if issue.state == 'open':
            inventory['summary']['open'] += 1
        else:
            inventory['summary']['closed'] += 1

        inventory['summary']['by_severity'][severity] = \
            inventory['summary']['by_severity'].get(severity, 0) + 1

    # Sort issues by severity then creation date
    severity_priority = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3, 'unknown': 4}
    inventory['issues'].sort(key=lambda x: (
        severity_priority.get(x['severity'], 4),
        x['created_at'],
    ))

    if output_path:
        with open(output_path, 'w') as f:
            json.dump(inventory, f, indent=2)
        logger.info(f"Report written to: {output_path}")

    return inventory


def close_resolved_cves(
    trivy_report: str,
    service: str,
    dry_run: bool = False,
) -> list[dict]:
    """Close issues for CVEs that are no longer detected."""
    # Get current CVEs from scan
    current_cves = {c['cve_id'] for c in parse_trivy_cves(trivy_report)}

    repo = get_repo()
    issues = repo.get_issues(state='open', labels=CVE_LABELS)

    closed = []

    for issue in issues:
        # Check if issue is for this service
        if service.lower() not in issue.title.lower():
            continue

        # Extract CVE ID from title
        import re
        cve_match = re.search(r'CVE-\d{4}-\d+', issue.title, re.IGNORECASE)
        if not cve_match:
            continue

        cve_id = cve_match.group(0).upper()

        # If CVE is no longer in scan results, close the issue
        if cve_id not in current_cves:
            if dry_run:
                logger.info(f"DRY RUN: Would close issue #{issue.number} ({cve_id})")
                closed.append({
                    'issue_number': issue.number,
                    'cve_id': cve_id,
                    'dry_run': True,
                })
            else:
                try:
                    issue.create_comment(
                        f"✅ **CVE Resolved**\n\n"
                        f"This vulnerability ({cve_id}) is no longer detected in the latest scan.\n\n"
                        f"_Automatically closed by A.R.C. CVE tracking._"
                    )
                    issue.edit(state='closed')
                    closed.append({
                        'issue_number': issue.number,
                        'cve_id': cve_id,
                    })
                    logger.info(f"Closed issue #{issue.number} ({cve_id})")
                except Exception as e:
                    logger.error(f"Failed to close issue #{issue.number}: {e}")

    return closed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest='command', required=True)

    # Check command
    check_parser = subparsers.add_parser('check', help='Check if CVE is tracked')
    check_parser.add_argument('--cve', required=True, help='CVE ID to check')
    check_parser.add_argument('--service', help='Service name to filter by')

    # Create command
    create_parser = subparsers.add_parser('create', help='Create issues for new CVEs')
    create_parser.add_argument('--trivy-report', required=True, help='Trivy JSON report')
    create_parser.add_argument('--service', required=True, help='Service name')
    create_parser.add_argument('--min-severity', default='CRITICAL',
                               choices=['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'])
    create_parser.add_argument('--dry-run', action='store_true')

    # Report command
    report_parser = subparsers.add_parser('report', help='Generate CVE inventory')
    report_parser.add_argument('--output', help='Output file path')

    # Close command
    close_parser = subparsers.add_parser('close', help='Close resolved CVE issues')
    close_parser.add_argument('--trivy-report', required=True, help='Current Trivy report')
    close_parser.add_argument('--service', required=True, help='Service name')
    close_parser.add_argument('--dry-run', action='store_true')

    args = parser.parse_args()

    if args.command == 'check':
        result = check_cve(args.cve, args.service)
        print(json.dumps(result, indent=2))
        sys.exit(0 if not result['is_tracked'] else 1)

    elif args.command == 'create':
        result = create_cve_issues(
            args.trivy_report,
            args.service,
            args.min_severity,
            args.dry_run,
        )
        print(json.dumps(result, indent=2))
        sys.exit(0)

    elif args.command == 'report':
        result = generate_report(args.output)
        if not args.output:
            print(json.dumps(result, indent=2))
        sys.exit(0)

    elif args.command == 'close':
        result = close_resolved_cves(
            args.trivy_report,
            args.service,
            args.dry_run,
        )
        print(json.dumps(result, indent=2))
        sys.exit(0)


if __name__ == '__main__':
    main()
