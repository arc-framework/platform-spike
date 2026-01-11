#!/usr/bin/env python3
"""
Analyze cache efficiency across workflow runs.

Calculates cache hit rates, identifies inefficient cache patterns,
and provides optimization recommendations.

Usage:
    python analyze-cache-efficiency.py --days 7
    python analyze-cache-efficiency.py --workflow "PR Checks" --output report.json

Environment Variables:
    GITHUB_TOKEN: GitHub token with actions:read permission
    GITHUB_REPOSITORY: Repository in owner/repo format
"""
import argparse
import json
import logging
import os
import re
import sys
from collections import defaultdict
from dataclasses import dataclass, asdict, field
from datetime import datetime, timedelta
from typing import Optional

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)


@dataclass
class CacheStats:
    """Statistics for a cache key pattern."""
    pattern: str
    hits: int = 0
    misses: int = 0
    partial_hits: int = 0
    total_size_bytes: int = 0
    avg_restore_time_ms: float = 0.0
    avg_save_time_ms: float = 0.0

    @property
    def hit_rate(self) -> float:
        total = self.hits + self.misses + self.partial_hits
        if total == 0:
            return 0.0
        return (self.hits + self.partial_hits * 0.5) / total * 100

    @property
    def total_accesses(self) -> int:
        return self.hits + self.misses + self.partial_hits


@dataclass
class CacheReport:
    """Cache efficiency report."""
    generated_at: str
    period_start: str
    period_end: str
    repository: str

    # Summary
    total_cache_operations: int = 0
    overall_hit_rate: float = 0.0
    total_cache_size_mb: float = 0.0
    estimated_time_saved_minutes: float = 0.0

    # By cache type
    by_cache_type: dict = field(default_factory=dict)

    # By workflow
    by_workflow: dict = field(default_factory=dict)

    # Issues
    issues: list = field(default_factory=list)

    # Recommendations
    recommendations: list = field(default_factory=list)


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


def extract_cache_key_pattern(key: str) -> str:
    """Extract the base pattern from a cache key."""
    # Remove hash suffixes
    pattern = re.sub(r'-[a-f0-9]{40,}', '-{hash}', key)
    # Remove SHA suffixes
    pattern = re.sub(r'-[a-f0-9]{7,}$', '-{sha}', pattern)
    # Remove date suffixes
    pattern = re.sub(r'-\d{8,}', '-{date}', pattern)
    return pattern


def analyze_workflow_logs(repo_name: str, since: datetime, until: datetime, workflow_filter: Optional[str] = None) -> dict:
    """Analyze workflow logs for cache operations."""
    g = get_github_client()
    repo = g.get_repo(repo_name)

    cache_operations = defaultdict(list)
    workflow_stats = defaultdict(lambda: {'hits': 0, 'misses': 0, 'partial': 0})

    # Note: This is a simplified analysis. Full analysis would require
    # parsing actual workflow logs which is API-intensive.

    # Get workflow runs
    for run in repo.get_workflow_runs(created=f">={since.strftime('%Y-%m-%d')}"):
        if run.created_at > until:
            continue
        if run.created_at < since:
            break

        if workflow_filter and workflow_filter.lower() not in run.name.lower():
            continue

        # Get jobs for this run
        try:
            for job in run.jobs():
                for step in job.steps:
                    step_name = step.name.lower() if step.name else ''

                    # Detect cache operations from step names
                    if 'cache' in step_name or 'restore' in step_name:
                        if step.conclusion == 'success':
                            # Heuristic: successful cache step likely means hit
                            workflow_stats[run.name]['hits'] += 1
                        elif step.conclusion == 'skipped':
                            # Skipped often means cache miss or save-only
                            workflow_stats[run.name]['misses'] += 1

        except Exception as e:
            logger.debug(f"Could not get jobs for run {run.id}: {e}")

    return dict(workflow_stats)


def get_cache_inventory(repo_name: str) -> list:
    """Get current cache inventory."""
    g = get_github_client()
    repo = g.get_repo(repo_name)

    caches = []

    # Use REST API for cache listing
    import requests
    token = os.environ.get('GITHUB_TOKEN')
    headers = {
        'Authorization': f'token {token}',
        'Accept': 'application/vnd.github+json'
    }

    url = f'https://api.github.com/repos/{repo_name}/actions/caches'
    page = 1

    while True:
        response = requests.get(f'{url}?page={page}&per_page=100', headers=headers)
        if response.status_code != 200:
            logger.warning(f"Failed to get caches: {response.status_code}")
            break

        data = response.json()
        page_caches = data.get('actions_caches', [])
        if not page_caches:
            break

        caches.extend(page_caches)
        page += 1

    return caches


def generate_report(caches: list, workflow_stats: dict, period_start: datetime, period_end: datetime) -> CacheReport:
    """Generate cache efficiency report."""
    report = CacheReport(
        generated_at=datetime.utcnow().isoformat(),
        period_start=period_start.isoformat(),
        period_end=period_end.isoformat(),
        repository=os.environ.get('GITHUB_REPOSITORY', 'unknown'),
    )

    # Analyze cache inventory
    cache_types = defaultdict(lambda: CacheStats(pattern=''))
    total_size = 0

    for cache in caches:
        key = cache.get('key', '')
        pattern = extract_cache_key_pattern(key)
        size = cache.get('size_in_bytes', 0)

        stats = cache_types[pattern]
        stats.pattern = pattern
        stats.total_size_bytes += size
        total_size += size

    report.total_cache_size_mb = total_size / (1024 * 1024)
    report.by_cache_type = {k: asdict(v) for k, v in cache_types.items()}

    # Analyze workflow stats
    total_hits = 0
    total_misses = 0

    for workflow, stats in workflow_stats.items():
        report.by_workflow[workflow] = {
            'hits': stats['hits'],
            'misses': stats['misses'],
            'partial': stats['partial'],
            'hit_rate': (stats['hits'] / max(stats['hits'] + stats['misses'], 1)) * 100
        }
        total_hits += stats['hits']
        total_misses += stats['misses']

    report.total_cache_operations = total_hits + total_misses
    report.overall_hit_rate = (total_hits / max(total_hits + total_misses, 1)) * 100

    # Estimate time saved (rough: 30 seconds per cache hit)
    report.estimated_time_saved_minutes = (total_hits * 30) / 60

    # Identify issues
    for pattern, stats in cache_types.items():
        if stats.total_size_bytes > 500 * 1024 * 1024:  # > 500MB
            report.issues.append({
                'type': 'large_cache',
                'pattern': pattern,
                'size_mb': stats.total_size_bytes / (1024 * 1024),
                'message': f'Cache pattern "{pattern}" is very large ({stats.total_size_bytes / (1024 * 1024):.0f} MB)'
            })

    for workflow, stats in report.by_workflow.items():
        if stats['hit_rate'] < 50 and (stats['hits'] + stats['misses']) >= 5:
            report.issues.append({
                'type': 'low_hit_rate',
                'workflow': workflow,
                'hit_rate': stats['hit_rate'],
                'message': f'Workflow "{workflow}" has low cache hit rate ({stats["hit_rate"]:.0f}%)'
            })

    # Generate recommendations
    if report.overall_hit_rate < 70:
        report.recommendations.append({
            'priority': 'high',
            'title': 'Improve Cache Key Strategy',
            'description': f'Overall hit rate is {report.overall_hit_rate:.0f}%. Consider using more specific restore-keys.',
            'actions': [
                'Add fallback restore keys with progressively shorter prefixes',
                'Use hashFiles() for dependency lock files',
                'Consider branch-based cache isolation',
            ]
        })

    if report.total_cache_size_mb > 5000:
        report.recommendations.append({
            'priority': 'medium',
            'title': 'Reduce Cache Size',
            'description': f'Total cache size is {report.total_cache_size_mb:.0f} MB. Large caches slow down restore.',
            'actions': [
                'Review what\'s being cached - exclude build outputs',
                'Use .gitignore patterns for cache paths',
                'Consider selective caching for large dependencies',
            ]
        })

    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        '--days',
        type=int,
        default=7,
        help='Number of days to analyze (default: 7)',
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

    args = parser.parse_args()

    repo_name = os.environ.get('GITHUB_REPOSITORY')
    if not repo_name:
        logger.error("GITHUB_REPOSITORY environment variable required")
        sys.exit(1)

    period_end = datetime.utcnow()
    period_start = period_end - timedelta(days=args.days)

    logger.info(f"Analyzing cache efficiency for {repo_name}")
    logger.info(f"Period: {period_start.date()} to {period_end.date()}")

    # Get cache inventory
    logger.info("Fetching cache inventory...")
    caches = get_cache_inventory(repo_name)
    logger.info(f"Found {len(caches)} caches")

    # Analyze workflow logs
    logger.info("Analyzing workflow logs...")
    workflow_stats = analyze_workflow_logs(repo_name, period_start, period_end, args.workflow)

    # Generate report
    report = generate_report(caches, workflow_stats, period_start, period_end)

    # Output
    if args.output:
        with open(args.output, 'w') as f:
            json.dump(asdict(report), f, indent=2)
        logger.info(f"Report written to: {args.output}")
    else:
        print(json.dumps(asdict(report), indent=2))

    # Summary
    print("\n" + "=" * 50)
    print("Cache Efficiency Summary")
    print("=" * 50)
    print(f"Total Caches: {len(caches)}")
    print(f"Total Size: {report.total_cache_size_mb:.1f} MB")
    print(f"Overall Hit Rate: {report.overall_hit_rate:.1f}%")
    print(f"Est. Time Saved: {report.estimated_time_saved_minutes:.1f} min")

    if report.issues:
        print(f"\nIssues Found: {len(report.issues)}")
        for issue in report.issues[:5]:
            print(f"  - {issue['message']}")

    if report.recommendations:
        print(f"\nRecommendations: {len(report.recommendations)}")
        for rec in report.recommendations:
            print(f"  [{rec['priority'].upper()}] {rec['title']}")


if __name__ == '__main__':
    main()
