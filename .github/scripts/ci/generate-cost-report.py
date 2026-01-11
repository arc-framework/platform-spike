#!/usr/bin/env python3
"""
Generate human-readable cost reports from CI/CD cost data.

Creates formatted reports for different audiences:
- Executive: High-level summary with projections
- Detailed: Full breakdown by workflow, branch, day
- Recommendations: Optimization suggestions

Usage:
    python generate-cost-report.py --input costs.json --format markdown
    python generate-cost-report.py --input costs.json --format html --output report.html
    python generate-cost-report.py --input costs.json --format github-summary

Output formats:
    markdown: GitHub-flavored markdown
    html: Standalone HTML report
    json: Processed data with recommendations
    github-summary: For $GITHUB_STEP_SUMMARY
"""
import argparse
import json
import logging
from datetime import datetime
from pathlib import Path
from typing import Optional

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)

# Cost thresholds for recommendations
THRESHOLDS = {
    'free_tier_warning': 70,  # Percent
    'free_tier_critical': 90,
    'high_failure_rate': 20,  # Percent
    'low_cache_hit_rate': 80,
    'expensive_workflow_minutes': 100,  # Per run average
}


def load_cost_data(input_path: Path) -> dict:
    """Load cost data from JSON file."""
    with open(input_path) as f:
        return json.load(f)


def generate_recommendations(data: dict) -> list[dict]:
    """Generate optimization recommendations based on cost data."""
    recommendations = []

    # Check free tier usage
    free_tier_used = data.get('free_tier_used_percent', 0)
    if free_tier_used >= THRESHOLDS['free_tier_critical']:
        recommendations.append({
            'severity': 'critical',
            'category': 'cost',
            'title': 'Free Tier Almost Exhausted',
            'description': f"Usage at {free_tier_used:.1f}%. Consider reducing workflow runs or optimizing build times.",
            'actions': [
                'Review and cancel unnecessary scheduled workflows',
                'Increase caching to reduce build times',
                'Consider self-hosted runners for heavy workloads',
            ],
        })
    elif free_tier_used >= THRESHOLDS['free_tier_warning']:
        recommendations.append({
            'severity': 'warning',
            'category': 'cost',
            'title': 'Free Tier Usage High',
            'description': f"Usage at {free_tier_used:.1f}%. Monitor closely.",
            'actions': [
                'Review daily usage patterns',
                'Identify workflows that can run less frequently',
            ],
        })

    # Check for high-failure workflows
    for name, wf_data in data.get('by_workflow', {}).items():
        if isinstance(wf_data, dict):
            total = wf_data.get('success_count', 0) + wf_data.get('failure_count', 0)
            if total > 0:
                failure_rate = (wf_data.get('failure_count', 0) / total) * 100
                if failure_rate >= THRESHOLDS['high_failure_rate']:
                    recommendations.append({
                        'severity': 'warning',
                        'category': 'reliability',
                        'title': f'High Failure Rate: {name}',
                        'description': f"{failure_rate:.1f}% failure rate wastes {wf_data.get('failure_count', 0)} runs.",
                        'actions': [
                            f'Investigate failures in {name}',
                            'Add better error handling',
                            'Consider adding pre-flight checks',
                        ],
                    })

    # Check for expensive workflows
    for name, wf_data in data.get('by_workflow', {}).items():
        if isinstance(wf_data, dict):
            runs = wf_data.get('runs', 0)
            if runs > 0:
                avg_minutes = wf_data.get('total_minutes', 0) / runs
                if avg_minutes >= THRESHOLDS['expensive_workflow_minutes']:
                    recommendations.append({
                        'severity': 'info',
                        'category': 'optimization',
                        'title': f'Long-Running Workflow: {name}',
                        'description': f"Average duration: {avg_minutes:.1f} minutes per run.",
                        'actions': [
                            'Review for parallelization opportunities',
                            'Check cache configuration',
                            'Consider splitting into smaller workflows',
                        ],
                    })

    # Check projection
    projected = data.get('projected_monthly_minutes', 0)
    if projected > 2000:
        overage = projected - 2000
        cost = overage * 0.008  # Linux pricing
        recommendations.append({
            'severity': 'warning',
            'category': 'cost',
            'title': 'Projected to Exceed Free Tier',
            'description': f"Projected {projected:.0f} min/month. Estimated overage cost: ${cost:.2f}",
            'actions': [
                'Reduce scheduled workflow frequency',
                'Implement more aggressive caching',
                'Cancel redundant PR checks on rapid pushes',
            ],
        })

    return recommendations


def generate_markdown_report(data: dict) -> str:
    """Generate markdown cost report."""
    recommendations = generate_recommendations(data)

    lines = [
        "# CI/CD Cost Report",
        "",
        f"**Period:** {data.get('period_start', '')[:10]} to {data.get('period_end', '')[:10]}",
        f"**Generated:** {data.get('generated_at', '')[:19]}",
        "",
        "## Summary",
        "",
        "| Metric | Value |",
        "|--------|-------|",
        f"| Total Runs | {data.get('total_runs', 0)} |",
        f"| Total Minutes | {data.get('total_minutes', 0):.1f} |",
        f"| Billable Minutes | {data.get('total_billable_minutes', 0):.1f} |",
        f"| Estimated Cost | ${data.get('total_cost_usd', 0):.2f} |",
        "",
    ]

    # Free tier gauge
    free_tier_used = data.get('free_tier_used_percent', 0)
    gauge = "🟢" if free_tier_used < 70 else "🟡" if free_tier_used < 90 else "🔴"
    lines.extend([
        f"### Free Tier Usage: {gauge} {free_tier_used:.1f}%",
        "",
        f"Using {data.get('total_billable_minutes', 0):.0f} of 2,000 minutes",
        "",
    ])

    # Projections
    lines.extend([
        "## 30-Day Projections",
        "",
        "| Metric | Value |",
        "|--------|-------|",
        f"| Daily Average | {data.get('daily_average_minutes', 0):.1f} min |",
        f"| Monthly Projection | {data.get('projected_monthly_minutes', 0):.0f} min |",
        f"| Projected Cost | ${data.get('projected_monthly_cost_usd', 0):.2f} |",
    ])

    days_left = data.get('days_until_free_tier_exhausted')
    if days_left is not None:
        if days_left > 0:
            lines.append(f"| Free Tier Exhausted In | ~{days_left} days |")
        else:
            lines.append("| Free Tier | ⚠️ EXHAUSTED |")

    lines.append("")

    # Top workflows
    lines.extend([
        "## Top Workflows by Usage",
        "",
        "| Workflow | Runs | Minutes | Avg Duration | Cost |",
        "|----------|------|---------|--------------|------|",
    ])

    for name, minutes in data.get('top_workflows', [])[:10]:
        wf_data = data.get('by_workflow', {}).get(name, {})
        if isinstance(wf_data, dict):
            runs = wf_data.get('runs', 0)
            avg = wf_data.get('avg_duration_minutes', 0)
            cost = wf_data.get('estimated_cost_usd', 0)
            lines.append(f"| {name} | {runs} | {minutes:.1f} | {avg:.1f} min | ${cost:.2f} |")

    lines.append("")

    # Top branches
    lines.extend([
        "## Top Branches by Usage",
        "",
        "| Branch | Minutes |",
        "|--------|---------|",
    ])

    for branch, minutes in data.get('top_branches', [])[:10]:
        lines.append(f"| `{branch}` | {minutes:.1f} |")

    lines.append("")

    # By trigger type
    lines.extend([
        "## Usage by Trigger",
        "",
        "| Trigger | Minutes |",
        "|---------|---------|",
    ])

    for trigger, minutes in sorted(data.get('by_trigger', {}).items(), key=lambda x: -x[1]):
        lines.append(f"| {trigger} | {minutes:.1f} |")

    lines.append("")

    # Recommendations
    if recommendations:
        lines.extend([
            "## Recommendations",
            "",
        ])

        for rec in recommendations:
            severity_icon = {
                'critical': '🔴',
                'warning': '🟡',
                'info': '🔵',
            }.get(rec['severity'], '⚪')

            lines.extend([
                f"### {severity_icon} {rec['title']}",
                "",
                rec['description'],
                "",
                "**Actions:**",
            ])

            for action in rec.get('actions', []):
                lines.append(f"- {action}")

            lines.append("")

    lines.extend([
        "---",
        "",
        "_Generated by A.R.C. Cost Report Generator_",
    ])

    return "\n".join(lines)


def generate_github_summary(data: dict) -> str:
    """Generate GitHub Actions step summary."""
    recommendations = generate_recommendations(data)

    lines = [
        "## 💰 CI/CD Cost Report",
        "",
    ]

    # Alert banner if needed
    free_tier_used = data.get('free_tier_used_percent', 0)
    if free_tier_used >= 90:
        lines.extend([
            "> 🔴 **ALERT:** Free tier usage at {:.1f}%!".format(free_tier_used),
            "",
        ])
    elif free_tier_used >= 70:
        lines.extend([
            "> 🟡 **Warning:** Free tier usage at {:.1f}%".format(free_tier_used),
            "",
        ])

    lines.extend([
        "### Summary",
        "",
        "| Metric | Value |",
        "|--------|-------|",
        f"| Total Runs | {data.get('total_runs', 0)} |",
        f"| Billable Minutes | {data.get('total_billable_minutes', 0):.0f} / 2,000 |",
        f"| Free Tier Used | {free_tier_used:.1f}% |",
        f"| Estimated Cost | ${data.get('total_cost_usd', 0):.2f} |",
        "",
    ])

    # Top consumers (condensed)
    lines.extend([
        "### Top Workflows",
        "",
    ])

    for name, minutes in data.get('top_workflows', [])[:5]:
        lines.append(f"- **{name}**: {minutes:.0f} min")

    lines.append("")

    # Recommendations (condensed)
    critical_recs = [r for r in recommendations if r['severity'] == 'critical']
    if critical_recs:
        lines.extend([
            "### ⚠️ Action Required",
            "",
        ])
        for rec in critical_recs:
            lines.append(f"- **{rec['title']}**: {rec['description']}")

    return "\n".join(lines)


def generate_html_report(data: dict) -> str:
    """Generate HTML cost report."""
    recommendations = generate_recommendations(data)
    free_tier_used = data.get('free_tier_used_percent', 0)

    gauge_color = '#10b981' if free_tier_used < 70 else '#f59e0b' if free_tier_used < 90 else '#ef4444'

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>A.R.C. CI/CD Cost Report</title>
    <style>
        :root {{
            --primary: #2563eb;
            --success: #10b981;
            --warning: #f59e0b;
            --danger: #ef4444;
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
            padding: 2rem;
        }}
        .container {{ max-width: 1000px; margin: 0 auto; }}
        h1 {{ color: var(--primary); margin-bottom: 1rem; }}
        h2 {{ margin-top: 2rem; margin-bottom: 1rem; color: var(--gray-700); }}
        .card {{
            background: white;
            border-radius: 0.5rem;
            padding: 1.5rem;
            margin-bottom: 1rem;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }}
        .gauge {{
            width: 100%;
            height: 20px;
            background: var(--gray-200);
            border-radius: 10px;
            overflow: hidden;
            margin: 1rem 0;
        }}
        .gauge-fill {{
            height: 100%;
            background: {gauge_color};
            width: {min(free_tier_used, 100)}%;
            transition: width 0.5s;
        }}
        .stats {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
        }}
        .stat {{
            text-align: center;
            padding: 1rem;
        }}
        .stat-value {{
            font-size: 2rem;
            font-weight: bold;
            color: var(--primary);
        }}
        .stat-label {{
            color: var(--gray-700);
            font-size: 0.875rem;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
            margin: 1rem 0;
        }}
        th, td {{
            padding: 0.75rem;
            text-align: left;
            border-bottom: 1px solid var(--gray-200);
        }}
        th {{ background: var(--gray-100); font-weight: 600; }}
        .alert {{
            padding: 1rem;
            border-radius: 0.5rem;
            margin-bottom: 1rem;
        }}
        .alert-critical {{ background: #fee2e2; border-left: 4px solid var(--danger); }}
        .alert-warning {{ background: #fef3c7; border-left: 4px solid var(--warning); }}
        .alert-info {{ background: #dbeafe; border-left: 4px solid var(--primary); }}
        footer {{ text-align: center; margin-top: 2rem; color: var(--gray-700); }}
    </style>
</head>
<body>
    <div class="container">
        <h1>💰 CI/CD Cost Report</h1>
        <p>Period: {data.get('period_start', '')[:10]} to {data.get('period_end', '')[:10]}</p>

        <div class="card">
            <h2>Free Tier Usage</h2>
            <div class="gauge">
                <div class="gauge-fill"></div>
            </div>
            <p style="text-align: center; font-size: 1.25rem;">
                <strong>{free_tier_used:.1f}%</strong> used
                ({data.get('total_billable_minutes', 0):.0f} / 2,000 minutes)
            </p>
        </div>

        <div class="card">
            <div class="stats">
                <div class="stat">
                    <div class="stat-value">{data.get('total_runs', 0)}</div>
                    <div class="stat-label">Total Runs</div>
                </div>
                <div class="stat">
                    <div class="stat-value">{data.get('total_minutes', 0):.0f}</div>
                    <div class="stat-label">Total Minutes</div>
                </div>
                <div class="stat">
                    <div class="stat-value">${data.get('total_cost_usd', 0):.2f}</div>
                    <div class="stat-label">Estimated Cost</div>
                </div>
                <div class="stat">
                    <div class="stat-value">{data.get('projected_monthly_minutes', 0):.0f}</div>
                    <div class="stat-label">Projected Monthly</div>
                </div>
            </div>
        </div>

        <h2>Top Workflows</h2>
        <div class="card">
            <table>
                <thead>
                    <tr><th>Workflow</th><th>Runs</th><th>Minutes</th><th>Avg Duration</th><th>Cost</th></tr>
                </thead>
                <tbody>
                    {''.join(f'''<tr>
                        <td>{name}</td>
                        <td>{data.get('by_workflow', {}).get(name, {}).get('runs', 0) if isinstance(data.get('by_workflow', {}).get(name), dict) else 0}</td>
                        <td>{minutes:.1f}</td>
                        <td>{data.get('by_workflow', {}).get(name, {}).get('avg_duration_minutes', 0) if isinstance(data.get('by_workflow', {}).get(name), dict) else 0:.1f} min</td>
                        <td>${data.get('by_workflow', {}).get(name, {}).get('estimated_cost_usd', 0) if isinstance(data.get('by_workflow', {}).get(name), dict) else 0:.2f}</td>
                    </tr>''' for name, minutes in data.get('top_workflows', [])[:10])}
                </tbody>
            </table>
        </div>

        {''.join(f'''<div class="alert alert-{rec['severity']}">
            <strong>{rec['title']}</strong><br>
            {rec['description']}
        </div>''' for rec in recommendations) if recommendations else ''}

        <footer>
            <p>Generated {datetime.utcnow().strftime('%Y-%m-%d %H:%M UTC')} by A.R.C. Cost Report Generator</p>
        </footer>
    </div>
</body>
</html>"""

    return html


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        '--input',
        type=Path,
        required=True,
        help='Input cost data JSON file',
    )
    parser.add_argument(
        '--format',
        choices=['markdown', 'html', 'json', 'github-summary'],
        default='markdown',
        help='Output format',
    )
    parser.add_argument(
        '--output',
        type=Path,
        default=None,
        help='Output file path (default: stdout)',
    )

    args = parser.parse_args()

    # Load data
    data = load_cost_data(args.input)

    # Generate report
    if args.format == 'markdown':
        report = generate_markdown_report(data)
    elif args.format == 'html':
        report = generate_html_report(data)
    elif args.format == 'github-summary':
        report = generate_github_summary(data)
    elif args.format == 'json':
        recommendations = generate_recommendations(data)
        data['recommendations'] = recommendations
        report = json.dumps(data, indent=2)
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
