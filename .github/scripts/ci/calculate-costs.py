#!/usr/bin/env python3
"""
Calculate CI/CD costs from GitHub Actions workflow runs.

Fetches workflow run data from GitHub API and calculates:
- Total minutes used
- Cost per workflow
- Cost per branch/PR
- Billable vs non-billable time

Usage:
    python calculate-costs.py --days 30 --output costs.json
    python calculate-costs.py --days 7 --workflow "PR Checks"
    python calculate-costs.py --since 2024-01-01 --output costs.json

Environment Variables:
    GITHUB_TOKEN: GitHub token with actions:read permission
    GITHUB_REPOSITORY: Repository in owner/repo format

Pricing (as of 2024):
    - Linux: $0.008/minute
    - Windows: $0.016/minute
    - macOS: $0.08/minute
    - Free tier: 2,000 minutes/month (Linux equivalent)
"""
import argparse
import json
import logging
import os
import sys
from collections import defaultdict
from dataclasses import dataclass, asdict, field
from datetime import datetime, timedelta
from typing import Optional

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)

# GitHub Actions pricing per minute (USD)
PRICING = {
    'ubuntu': 0.008,
    'windows': 0.016,
    'macos': 0.08,
    'linux': 0.008,  # Alias
}

# Minute multipliers for free tier calculation
MULTIPLIERS = {
    'ubuntu': 1,
    'windows': 2,
    'macos': 10,
    'linux': 1,
}

# Free tier limits
FREE_TIER_MINUTES = 2000  # Linux-equivalent minutes per month


@dataclass
class WorkflowCost:
    """Cost data for a single workflow."""
    name: str
    runs: int = 0
    total_minutes: float = 0.0
    billable_minutes: float = 0.0
    linux_minutes: float = 0.0
    windows_minutes: float = 0.0
    macos_minutes: float = 0.0
    estimated_cost_usd: float = 0.0
    avg_duration_minutes: float = 0.0
    success_count: int = 0
    failure_count: int = 0


@dataclass
class CostReport:
    """Complete cost report."""
    generated_at: str
    period_start: str
    period_end: str
    repository: str

    # Summary
    total_runs: int = 0
    total_minutes: float = 0.0
    total_billable_minutes: float = 0.0
    total_cost_usd: float = 0.0
    free_tier_used_percent: float = 0.0

    # Breakdown
    by_workflow: dict = field(default_factory=dict)
    by_branch: dict = field(default_factory=dict)
    by_trigger: dict = field(default_factory=dict)
    by_day: dict = field(default_factory=dict)

    # Top consumers
    top_workflows: list = field(default_factory=list)
    top_branches: list = field(default_factory=list)

    # Projections
    daily_average_minutes: float = 0.0
    projected_monthly_minutes: float = 0.0
    projected_monthly_cost_usd: float = 0.0
    days_until_free_tier_exhausted: Optional[int] = None


def get_github_client():
    """Get authenticated GitHub client."""
    try:
        from github import Github
        token = os.environ.get('GITHUB_TOKEN')
        if not token:
            raise ValueError("GITHUB_TOKEN environment variable required")
        return Github(token)
    except ImportError:
        logger.error("PyGithub required. Run: pip install PyGithub")
        sys.exit(1)


def fetch_workflow_runs(repo_name: str, since: datetime, until: datetime) -> list:
    """Fetch workflow runs from GitHub API."""
    g = get_github_client()
    repo = g.get_repo(repo_name)

    runs = []

    # Fetch all workflow runs in date range
    for run in repo.get_workflow_runs(created=f">={since.strftime('%Y-%m-%d')}"):
        if run.created_at > until:
            continue
        if run.created_at < since:
            break

        # Get run timing
        timing = None
        try:
            timing = run.timing()
        except Exception:
            pass

        run_data = {
            'id': run.id,
            'name': run.name,
            'workflow_id': run.workflow_id,
            'status': run.status,
            'conclusion': run.conclusion,
            'created_at': run.created_at.isoformat(),
            'updated_at': run.updated_at.isoformat() if run.updated_at else None,
            'head_branch': run.head_branch,
            'event': run.event,
            'run_attempt': run.run_attempt,
        }

        # Calculate duration
        if run.created_at and run.updated_at:
            duration = (run.updated_at - run.created_at).total_seconds() / 60
            run_data['duration_minutes'] = duration
        else:
            run_data['duration_minutes'] = 0

        # Get billable time from timing if available
        if timing:
            run_data['billable'] = {
                'UBUNTU': timing.billable.get('UBUNTU', {}).get('total_ms', 0) / 60000,
                'WINDOWS': timing.billable.get('WINDOWS', {}).get('total_ms', 0) / 60000,
                'MACOS': timing.billable.get('MACOS', {}).get('total_ms', 0) / 60000,
            }
        else:
            # Estimate based on runner (assume Linux)
            run_data['billable'] = {
                'UBUNTU': run_data['duration_minutes'],
                'WINDOWS': 0,
                'MACOS': 0,
            }

        runs.append(run_data)

    return runs


def calculate_costs(runs: list, period_start: datetime, period_end: datetime) -> CostReport:
    """Calculate costs from workflow runs."""
    report = CostReport(
        generated_at=datetime.utcnow().isoformat(),
        period_start=period_start.isoformat(),
        period_end=period_end.isoformat(),
        repository=os.environ.get('GITHUB_REPOSITORY', 'unknown'),
    )

    workflows = defaultdict(lambda: WorkflowCost(name=''))
    branches = defaultdict(float)
    triggers = defaultdict(float)
    days = defaultdict(float)

    for run in runs:
        name = run.get('name', 'Unknown')
        branch = run.get('head_branch', 'unknown')
        event = run.get('event', 'unknown')
        created = run.get('created_at', '')[:10]  # Date only

        billable = run.get('billable', {})
        linux_mins = billable.get('UBUNTU', 0)
        windows_mins = billable.get('WINDOWS', 0)
        macos_mins = billable.get('MACOS', 0)

        # Calculate billable minutes (with multipliers)
        billable_mins = (
            linux_mins * MULTIPLIERS['ubuntu'] +
            windows_mins * MULTIPLIERS['windows'] +
            macos_mins * MULTIPLIERS['macos']
        )

        # Calculate cost
        cost = (
            linux_mins * PRICING['ubuntu'] +
            windows_mins * PRICING['windows'] +
            macos_mins * PRICING['macos']
        )

        # Update workflow stats
        wf = workflows[name]
        wf.name = name
        wf.runs += 1
        wf.total_minutes += run.get('duration_minutes', 0)
        wf.billable_minutes += billable_mins
        wf.linux_minutes += linux_mins
        wf.windows_minutes += windows_mins
        wf.macos_minutes += macos_mins
        wf.estimated_cost_usd += cost

        if run.get('conclusion') == 'success':
            wf.success_count += 1
        elif run.get('conclusion') == 'failure':
            wf.failure_count += 1

        # Update aggregations
        branches[branch] += billable_mins
        triggers[event] += billable_mins
        days[created] += billable_mins

        # Update totals
        report.total_runs += 1
        report.total_minutes += run.get('duration_minutes', 0)
        report.total_billable_minutes += billable_mins
        report.total_cost_usd += cost

    # Calculate averages
    for name, wf in workflows.items():
        if wf.runs > 0:
            wf.avg_duration_minutes = wf.total_minutes / wf.runs

    # Convert to report format
    report.by_workflow = {k: asdict(v) for k, v in workflows.items()}
    report.by_branch = dict(branches)
    report.by_trigger = dict(triggers)
    report.by_day = dict(days)

    # Top consumers
    report.top_workflows = sorted(
        [(k, v.billable_minutes) for k, v in workflows.items()],
        key=lambda x: -x[1]
    )[:10]

    report.top_branches = sorted(
        branches.items(),
        key=lambda x: -x[1]
    )[:10]

    # Free tier calculation
    report.free_tier_used_percent = (report.total_billable_minutes / FREE_TIER_MINUTES) * 100

    # Projections
    num_days = (period_end - period_start).days or 1
    report.daily_average_minutes = report.total_billable_minutes / num_days
    report.projected_monthly_minutes = report.daily_average_minutes * 30
    report.projected_monthly_cost_usd = (
        max(0, report.projected_monthly_minutes - FREE_TIER_MINUTES) * PRICING['ubuntu']
    )

    # Days until free tier exhausted
    if report.daily_average_minutes > 0:
        remaining_minutes = FREE_TIER_MINUTES - report.total_billable_minutes
        if remaining_minutes > 0:
            report.days_until_free_tier_exhausted = int(remaining_minutes / report.daily_average_minutes)
        else:
            report.days_until_free_tier_exhausted = 0

    return report


def generate_summary(report: CostReport) -> str:
    """Generate text summary of cost report."""
    lines = [
        "=" * 60,
        "GitHub Actions Cost Report",
        "=" * 60,
        "",
        f"Period: {report.period_start[:10]} to {report.period_end[:10]}",
        f"Repository: {report.repository}",
        "",
        "SUMMARY",
        "-" * 40,
        f"Total Runs: {report.total_runs}",
        f"Total Minutes: {report.total_minutes:.1f}",
        f"Billable Minutes: {report.total_billable_minutes:.1f}",
        f"Estimated Cost: ${report.total_cost_usd:.2f}",
        "",
        f"Free Tier Used: {report.free_tier_used_percent:.1f}% of {FREE_TIER_MINUTES} min",
        "",
        "PROJECTIONS (30-day)",
        "-" * 40,
        f"Daily Average: {report.daily_average_minutes:.1f} min",
        f"Projected Monthly: {report.projected_monthly_minutes:.1f} min",
        f"Projected Cost: ${report.projected_monthly_cost_usd:.2f}",
    ]

    if report.days_until_free_tier_exhausted is not None:
        if report.days_until_free_tier_exhausted > 0:
            lines.append(f"Free Tier Exhausted In: ~{report.days_until_free_tier_exhausted} days")
        else:
            lines.append("Free Tier: EXHAUSTED")

    lines.extend([
        "",
        "TOP WORKFLOWS BY MINUTES",
        "-" * 40,
    ])

    for name, minutes in report.top_workflows[:5]:
        lines.append(f"  {name}: {minutes:.1f} min")

    lines.extend([
        "",
        "TOP BRANCHES BY MINUTES",
        "-" * 40,
    ])

    for branch, minutes in report.top_branches[:5]:
        lines.append(f"  {branch}: {minutes:.1f} min")

    lines.extend([
        "",
        "=" * 60,
    ])

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        '--days',
        type=int,
        default=30,
        help='Number of days to analyze (default: 30)',
    )
    parser.add_argument(
        '--since',
        type=str,
        default=None,
        help='Start date (YYYY-MM-DD)',
    )
    parser.add_argument(
        '--until',
        type=str,
        default=None,
        help='End date (YYYY-MM-DD)',
    )
    parser.add_argument(
        '--workflow',
        type=str,
        default=None,
        help='Filter by workflow name',
    )
    parser.add_argument(
        '--output',
        type=str,
        default=None,
        help='Output JSON file path',
    )
    parser.add_argument(
        '--summary',
        action='store_true',
        help='Print summary to stdout',
    )

    args = parser.parse_args()

    # Determine date range
    if args.since:
        period_start = datetime.fromisoformat(args.since)
    else:
        period_start = datetime.utcnow() - timedelta(days=args.days)

    if args.until:
        period_end = datetime.fromisoformat(args.until)
    else:
        period_end = datetime.utcnow()

    repo_name = os.environ.get('GITHUB_REPOSITORY')
    if not repo_name:
        logger.error("GITHUB_REPOSITORY environment variable required")
        sys.exit(1)

    logger.info(f"Fetching workflow runs from {period_start.date()} to {period_end.date()}")

    # Fetch runs
    runs = fetch_workflow_runs(repo_name, period_start, period_end)
    logger.info(f"Found {len(runs)} workflow runs")

    # Filter by workflow if specified
    if args.workflow:
        runs = [r for r in runs if args.workflow.lower() in r.get('name', '').lower()]
        logger.info(f"Filtered to {len(runs)} runs matching '{args.workflow}'")

    # Calculate costs
    report = calculate_costs(runs, period_start, period_end)

    # Output
    if args.output:
        with open(args.output, 'w') as f:
            json.dump(asdict(report), f, indent=2, default=str)
        logger.info(f"Report written to: {args.output}")

    if args.summary or not args.output:
        print(generate_summary(report))

    # Exit with warning if approaching limit
    if report.free_tier_used_percent >= 80:
        logger.warning(f"Free tier usage at {report.free_tier_used_percent:.1f}%!")
        sys.exit(2)


if __name__ == '__main__':
    main()
