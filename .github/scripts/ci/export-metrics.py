#!/usr/bin/env python3
"""
Export workflow metrics for dashboards and analysis.

Collects metrics from workflow runs and exports them in various formats
for visualization and performance tracking.

Usage:
    python export-metrics.py --workflow-run-id 12345 --output metrics.json
    python export-metrics.py --collect-from-artifacts --output metrics.json
    python export-metrics.py --aggregate-history --days 30 --output trends.json

Metrics collected:
    - build_time_seconds: Total build duration
    - image_size_mb: Docker image size
    - cache_hit_rate: BuildKit cache hit percentage
    - cve_count: Number of vulnerabilities by severity
    - validation_pass_rate: Percentage of checks passing

Environment Variables:
    GITHUB_TOKEN: GitHub token for API access
    GITHUB_REPOSITORY: Repository in owner/repo format
"""
import argparse
import json
import logging
import os
import sys
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta
from typing import Optional

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)


@dataclass
class WorkflowMetrics:
    """Metrics for a single workflow run."""
    workflow_run_id: int
    workflow_name: str
    timestamp: str
    branch: str
    commit_sha: str
    status: str
    duration_seconds: int

    # Build metrics
    build_count: int = 0
    build_success_count: int = 0
    total_build_time_seconds: int = 0
    avg_build_time_seconds: float = 0.0
    total_image_size_mb: float = 0.0
    cache_hit_rate: float = 0.0

    # Security metrics
    cve_critical: int = 0
    cve_high: int = 0
    cve_medium: int = 0
    cve_low: int = 0
    cve_total: int = 0

    # Validation metrics
    validation_total: int = 0
    validation_passed: int = 0
    validation_failed: int = 0
    validation_pass_rate: float = 0.0


@dataclass
class MetricsTrend:
    """Aggregated metrics over time."""
    period_start: str
    period_end: str
    run_count: int

    # Averages
    avg_duration_seconds: float
    avg_build_time_seconds: float
    avg_cache_hit_rate: float
    avg_validation_pass_rate: float

    # Totals
    total_cve_critical: int
    total_cve_high: int

    # Success rates
    workflow_success_rate: float
    build_success_rate: float


def parse_duration(duration_str: str) -> int:
    """Parse duration string (e.g., '2m 15s') to seconds."""
    if not duration_str or duration_str == '-':
        return 0

    seconds = 0
    import re

    # Match hours, minutes, seconds
    hours = re.search(r'(\d+)h', duration_str)
    minutes = re.search(r'(\d+)m', duration_str)
    secs = re.search(r'(\d+)s', duration_str)

    if hours:
        seconds += int(hours.group(1)) * 3600
    if minutes:
        seconds += int(minutes.group(1)) * 60
    if secs:
        seconds += int(secs.group(1))

    return seconds


def parse_size(size_str: str) -> float:
    """Parse size string (e.g., '256MB') to MB."""
    if not size_str or size_str == '-':
        return 0.0

    import re
    match = re.search(r'([\d.]+)\s*(GB|MB|KB|B)?', size_str, re.IGNORECASE)
    if not match:
        return 0.0

    value = float(match.group(1))
    unit = (match.group(2) or 'B').upper()

    multipliers = {'B': 1/1024/1024, 'KB': 1/1024, 'MB': 1, 'GB': 1024}
    return value * multipliers.get(unit, 1)


def collect_metrics_from_results(results_path: str, run_context: dict) -> WorkflowMetrics:
    """Collect metrics from a results JSON file."""
    with open(results_path) as f:
        results = json.load(f)

    metrics = WorkflowMetrics(
        workflow_run_id=run_context.get('run_id', 0),
        workflow_name=run_context.get('workflow_name', 'unknown'),
        timestamp=datetime.utcnow().isoformat(),
        branch=run_context.get('branch', 'unknown'),
        commit_sha=run_context.get('commit_sha', 'unknown'),
        status=run_context.get('status', 'unknown'),
        duration_seconds=run_context.get('duration_seconds', 0),
    )

    # Build metrics
    builds = results.get('builds', [])
    if builds:
        metrics.build_count = len(builds)
        metrics.build_success_count = sum(1 for b in builds if b.get('status') == 'success')

        total_time = sum(parse_duration(b.get('duration', '0s')) for b in builds)
        metrics.total_build_time_seconds = total_time
        metrics.avg_build_time_seconds = total_time / len(builds) if builds else 0

        total_size = sum(parse_size(b.get('size', '0MB')) for b in builds)
        metrics.total_image_size_mb = total_size

        # Cache hit rate (average across builds)
        cache_hits = []
        for b in builds:
            cache_str = b.get('cache_hit', '0%')
            if cache_str and cache_str != '-':
                try:
                    cache_hits.append(float(cache_str.replace('%', '')))
                except ValueError:
                    pass
        if cache_hits:
            metrics.cache_hit_rate = sum(cache_hits) / len(cache_hits)

    # Security metrics
    vulns = results.get('vulnerabilities', {})
    if vulns:
        metrics.cve_critical = vulns.get('CRITICAL', 0)
        metrics.cve_high = vulns.get('HIGH', 0)
        metrics.cve_medium = vulns.get('MEDIUM', 0)
        metrics.cve_low = vulns.get('LOW', 0)
        metrics.cve_total = sum([
            metrics.cve_critical,
            metrics.cve_high,
            metrics.cve_medium,
            metrics.cve_low,
        ])

    # Validation metrics
    checks = results.get('checks', [])
    if checks:
        metrics.validation_total = len(checks)
        metrics.validation_passed = sum(1 for c in checks if c.get('passed'))
        metrics.validation_failed = metrics.validation_total - metrics.validation_passed
        metrics.validation_pass_rate = (
            metrics.validation_passed / metrics.validation_total * 100
            if metrics.validation_total > 0 else 100.0
        )

    return metrics


def collect_metrics_from_api(run_id: int) -> Optional[WorkflowMetrics]:
    """Collect metrics from GitHub API for a workflow run."""
    try:
        from github import Github
    except ImportError:
        logger.error("PyGithub required. Run: pip install PyGithub")
        return None

    token = os.environ.get('GITHUB_TOKEN')
    repo_name = os.environ.get('GITHUB_REPOSITORY')

    if not token or not repo_name:
        logger.error("GITHUB_TOKEN and GITHUB_REPOSITORY required")
        return None

    g = Github(token)
    repo = g.get_repo(repo_name)
    run = repo.get_workflow_run(run_id)

    # Calculate duration
    duration = 0
    if run.created_at and run.updated_at:
        duration = int((run.updated_at - run.created_at).total_seconds())

    metrics = WorkflowMetrics(
        workflow_run_id=run.id,
        workflow_name=run.name or 'unknown',
        timestamp=run.created_at.isoformat() if run.created_at else datetime.utcnow().isoformat(),
        branch=run.head_branch or 'unknown',
        commit_sha=run.head_sha or 'unknown',
        status=run.conclusion or run.status or 'unknown',
        duration_seconds=duration,
    )

    return metrics


def aggregate_metrics(metrics_list: list[WorkflowMetrics]) -> MetricsTrend:
    """Aggregate multiple metrics into a trend summary."""
    if not metrics_list:
        return None

    run_count = len(metrics_list)

    # Calculate averages
    avg_duration = sum(m.duration_seconds for m in metrics_list) / run_count
    avg_build_time = sum(m.avg_build_time_seconds for m in metrics_list) / run_count
    avg_cache_hit = sum(m.cache_hit_rate for m in metrics_list) / run_count
    avg_validation = sum(m.validation_pass_rate for m in metrics_list) / run_count

    # Calculate totals
    total_critical = sum(m.cve_critical for m in metrics_list)
    total_high = sum(m.cve_high for m in metrics_list)

    # Calculate success rates
    success_runs = sum(1 for m in metrics_list if m.status == 'success')
    workflow_success_rate = success_runs / run_count * 100

    total_builds = sum(m.build_count for m in metrics_list)
    successful_builds = sum(m.build_success_count for m in metrics_list)
    build_success_rate = successful_builds / total_builds * 100 if total_builds > 0 else 100.0

    # Get period bounds
    timestamps = [m.timestamp for m in metrics_list]
    timestamps.sort()

    return MetricsTrend(
        period_start=timestamps[0],
        period_end=timestamps[-1],
        run_count=run_count,
        avg_duration_seconds=avg_duration,
        avg_build_time_seconds=avg_build_time,
        avg_cache_hit_rate=avg_cache_hit,
        avg_validation_pass_rate=avg_validation,
        total_cve_critical=total_critical,
        total_cve_high=total_high,
        workflow_success_rate=workflow_success_rate,
        build_success_rate=build_success_rate,
    )


def export_metrics(
    metrics: WorkflowMetrics,
    output_path: Optional[str],
    output_format: str = 'json',
) -> str:
    """Export metrics to file or stdout."""
    data = asdict(metrics)

    if output_format == 'json':
        output = json.dumps(data, indent=2)
    elif output_format == 'prometheus':
        # Prometheus exposition format
        lines = []
        prefix = 'arc_ci'
        labels = f'workflow="{metrics.workflow_name}",branch="{metrics.branch}"'

        lines.append(f'{prefix}_duration_seconds{{{labels}}} {metrics.duration_seconds}')
        lines.append(f'{prefix}_build_time_seconds{{{labels}}} {metrics.total_build_time_seconds}')
        lines.append(f'{prefix}_cache_hit_rate{{{labels}}} {metrics.cache_hit_rate}')
        lines.append(f'{prefix}_cve_critical{{{labels}}} {metrics.cve_critical}')
        lines.append(f'{prefix}_cve_high{{{labels}}} {metrics.cve_high}')
        lines.append(f'{prefix}_validation_pass_rate{{{labels}}} {metrics.validation_pass_rate}')

        output = '\n'.join(lines)
    else:
        # CSV format
        headers = list(data.keys())
        values = [str(v) for v in data.values()]
        output = ','.join(headers) + '\n' + ','.join(values)

    if output_path:
        with open(output_path, 'w') as f:
            f.write(output)
        logger.info(f"Metrics written to: {output_path}")
    else:
        print(output)

    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        '--workflow-run-id',
        type=int,
        default=int(os.environ.get('GITHUB_RUN_ID', 0)),
        help='Workflow run ID to collect metrics from',
    )
    parser.add_argument(
        '--results-file',
        type=str,
        default=None,
        help='Path to results JSON file',
    )
    parser.add_argument(
        '--output',
        type=str,
        default=None,
        help='Output file path (default: stdout)',
    )
    parser.add_argument(
        '--format',
        choices=['json', 'prometheus', 'csv'],
        default='json',
        help='Output format',
    )
    parser.add_argument(
        '--branch',
        type=str,
        default=os.environ.get('GITHUB_HEAD_REF', os.environ.get('GITHUB_REF_NAME', 'unknown')),
        help='Branch name',
    )
    parser.add_argument(
        '--commit-sha',
        type=str,
        default=os.environ.get('GITHUB_SHA', 'unknown'),
        help='Commit SHA',
    )

    args = parser.parse_args()

    run_context = {
        'run_id': args.workflow_run_id,
        'workflow_name': os.environ.get('GITHUB_WORKFLOW', 'unknown'),
        'branch': args.branch,
        'commit_sha': args.commit_sha,
        'status': 'success',  # Will be overridden if results file provided
        'duration_seconds': 0,
    }

    # Collect metrics
    if args.results_file:
        metrics = collect_metrics_from_results(args.results_file, run_context)
    elif args.workflow_run_id:
        metrics = collect_metrics_from_api(args.workflow_run_id)
        if not metrics:
            logger.error("Failed to collect metrics from API")
            sys.exit(1)
    else:
        logger.error("Either --results-file or --workflow-run-id required")
        sys.exit(1)

    # Export metrics
    export_metrics(metrics, args.output, args.format)


if __name__ == '__main__':
    main()
