#!/usr/bin/env python3
"""
Post or update PR comment with workflow results.

Creates a formatted comment on a PR with build/test results,
updating an existing comment if one exists (to avoid spam).

Usage:
    python post-pr-comment.py --results results.json --pr 123
    python post-pr-comment.py --results results.json --pr 123 --update-existing
    python post-pr-comment.py --quick-stats "✅ 5 passed, ❌ 1 failed" --pr 123

Environment Variables:
    GITHUB_TOKEN: GitHub token with PR comment permission
    GITHUB_REPOSITORY: Repository in owner/repo format
"""
import argparse
import json
import logging
import os
import re
import sys
from datetime import datetime
from typing import Optional

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)

# Marker to identify our comments for updating
COMMENT_MARKER = '<!-- arc-ci-results -->'


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


def find_existing_comment(pr, marker: str = COMMENT_MARKER):
    """Find existing bot comment with marker."""
    for comment in pr.get_issue_comments():
        if marker in (comment.body or ''):
            return comment
    return None


def generate_comment_body(
    results: Optional[dict],
    quick_stats: Optional[str],
    workflow_url: Optional[str],
    commit_sha: Optional[str],
) -> str:
    """Generate formatted PR comment body."""
    lines = [
        COMMENT_MARKER,
        '## 🤖 A.R.C. CI/CD Results',
        '',
    ]

    # Quick stats header
    if quick_stats:
        lines.append(f'**Status:** {quick_stats}')
        lines.append('')

    # Commit info
    if commit_sha:
        lines.append(f'**Commit:** `{commit_sha[:7]}`')

    # Workflow link
    if workflow_url:
        lines.append(f'**Details:** [View workflow run]({workflow_url})')

    lines.append('')

    # Process detailed results if provided
    if results:
        # Build results
        builds = results.get('builds', [])
        if builds:
            lines.extend([
                '### 🏗️ Builds',
                '',
                '| Service | Status | Duration |',
                '|---------|--------|----------|',
            ])
            for build in builds:
                status_emoji = '✅' if build.get('status') == 'success' else '❌'
                lines.append(
                    f"| {build.get('service', '-')} | {status_emoji} | {build.get('duration', '-')} |"
                )
            lines.append('')

        # Validation results
        checks = results.get('checks', [])
        if checks:
            failed_checks = [c for c in checks if not c.get('passed')]
            if failed_checks:
                lines.extend([
                    '### ❌ Failed Checks',
                    '',
                ])
                for check in failed_checks[:5]:  # Limit to 5
                    lines.append(f"- **{check.get('name')}**: {check.get('details', 'No details')}")
                    if check.get('file'):
                        lines.append(f"  - File: `{check.get('file')}`")
                if len(failed_checks) > 5:
                    lines.append(f"- _...and {len(failed_checks) - 5} more_")
                lines.append('')

        # Security results
        vulns = results.get('vulnerabilities', {})
        if vulns:
            critical = vulns.get('CRITICAL', 0)
            high = vulns.get('HIGH', 0)

            if critical > 0 or high > 0:
                lines.extend([
                    '### 🔒 Security',
                    '',
                ])
                if critical > 0:
                    lines.append(f'🔴 **{critical} CRITICAL** vulnerabilities found')
                if high > 0:
                    lines.append(f'🟠 **{high} HIGH** vulnerabilities found')
                lines.append('')

        # Errors with suggested fixes
        errors = results.get('errors', [])
        if errors:
            lines.extend([
                '### 💡 Suggested Fixes',
                '',
            ])
            for error in errors[:3]:  # Limit to 3
                lines.append(f"**{error.get('type', 'Error')}**")
                if error.get('file'):
                    lines.append(f"- File: `{error.get('file')}`")
                if error.get('fix'):
                    lines.append(f"- Fix: {error.get('fix')}")
                lines.append('')

    # Footer
    lines.extend([
        '---',
        f'_Updated {datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC")} • '
        f'[Full summary]({workflow_url or "#"}) • '
        f'A.R.C. CI/CD_',
    ])

    return '\n'.join(lines)


def post_or_update_comment(
    pr_number: int,
    body: str,
    update_existing: bool = True,
) -> str:
    """Post new comment or update existing one."""
    g = get_github_client()
    repo_name = os.environ.get('GITHUB_REPOSITORY')

    if not repo_name:
        raise ValueError("GITHUB_REPOSITORY environment variable required")

    repo = g.get_repo(repo_name)
    pr = repo.get_pull(pr_number)

    if update_existing:
        existing = find_existing_comment(pr)
        if existing:
            existing.edit(body)
            logger.info(f"Updated existing comment: {existing.html_url}")
            return existing.html_url

    # Create new comment
    comment = pr.create_issue_comment(body)
    logger.info(f"Created new comment: {comment.html_url}")
    return comment.html_url


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        '--pr',
        type=int,
        required=True,
        help='PR number',
    )
    parser.add_argument(
        '--results',
        type=str,
        default=None,
        help='Path to results JSON file',
    )
    parser.add_argument(
        '--quick-stats',
        type=str,
        default=None,
        help='Quick stats string (e.g., "✅ 5 passed, ❌ 1 failed")',
    )
    parser.add_argument(
        '--workflow-url',
        type=str,
        default=os.environ.get('GITHUB_WORKFLOW_URL'),
        help='URL to workflow run',
    )
    parser.add_argument(
        '--commit-sha',
        type=str,
        default=os.environ.get('GITHUB_SHA'),
        help='Commit SHA',
    )
    parser.add_argument(
        '--update-existing',
        action='store_true',
        default=True,
        help='Update existing comment instead of creating new (default: true)',
    )
    parser.add_argument(
        '--no-update',
        action='store_true',
        help='Always create new comment',
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Print comment body without posting',
    )

    args = parser.parse_args()

    # Load results if provided
    results = None
    if args.results:
        try:
            with open(args.results) as f:
                results = json.load(f)
        except Exception as e:
            logger.warning(f"Failed to load results file: {e}")

    # Build workflow URL from environment if not provided
    workflow_url = args.workflow_url
    if not workflow_url:
        server = os.environ.get('GITHUB_SERVER_URL', 'https://github.com')
        repo = os.environ.get('GITHUB_REPOSITORY', '')
        run_id = os.environ.get('GITHUB_RUN_ID', '')
        if repo and run_id:
            workflow_url = f"{server}/{repo}/actions/runs/{run_id}"

    # Generate comment body
    body = generate_comment_body(
        results=results,
        quick_stats=args.quick_stats,
        workflow_url=workflow_url,
        commit_sha=args.commit_sha,
    )

    if args.dry_run:
        print("=" * 60)
        print("DRY RUN - Would post comment:")
        print("=" * 60)
        print(body)
        print("=" * 60)
        return

    # Post or update comment
    update_existing = args.update_existing and not args.no_update
    url = post_or_update_comment(args.pr, body, update_existing)
    print(f"Comment URL: {url}")


if __name__ == '__main__':
    main()
