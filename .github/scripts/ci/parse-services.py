#!/usr/bin/env python3
"""
Parse SERVICE.MD and extract service matrix for GitHub Actions.

Reads the SERVICE.MD file and outputs a JSON array of services that can be
used in GitHub Actions matrix strategy.

Usage:
    python parse-services.py > services.json
    python parse-services.py --type INFRA > infra-services.json
    python parse-services.py --filter "arc-brain,arc-voice" > subset.json
"""
import argparse
import json
import logging
import re
import sys
from pathlib import Path

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)


def parse_service_table(content: str) -> list[dict]:
    """Parse the master service table from SERVICE.MD content."""
    services = []

    # Find table rows (lines starting with |)
    table_pattern = re.compile(
        r'\|\s*\*\*([^*]+)\*\*\s*\|'  # Service name (bold)
        r'\s*`([^`]+)`\s*\|'          # A.R.C. Image
        r'\s*(\w+)\s*\|'              # Type
        r'\s*`?([^|`]+)`?\s*\|'       # Upstream Source
        r'\s*\*\*([^*]+)\*\*\s*\|'    # Codename (bold)
        r'\s*([^|]+)\|'               # Role
    )

    for match in table_pattern.finditer(content):
        service_name = match.group(1).strip()
        arc_image = match.group(2).strip()
        service_type = match.group(3).strip()
        upstream = match.group(4).strip()
        codename = match.group(5).strip()
        role = match.group(6).strip()

        # Determine if this is a buildable service (has local path)
        is_buildable = upstream.startswith('./')

        # Extract path for buildable services
        build_path = upstream if is_buildable else None

        services.append({
            'name': service_name.lower(),
            'image': arc_image,
            'type': service_type,
            'upstream': upstream,
            'codename': codename,
            'role': role,
            'buildable': is_buildable,
            'path': build_path,
        })

    return services


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        '--service-md',
        type=Path,
        default=Path('SERVICE.MD'),
        help='Path to SERVICE.MD file (default: SERVICE.MD)',
    )
    parser.add_argument(
        '--type',
        choices=['INFRA', 'CORE', 'WORKER', 'SIDECAR', 'ALL'],
        default='ALL',
        help='Filter by service type',
    )
    parser.add_argument(
        '--buildable-only',
        action='store_true',
        help='Only include buildable services (local paths)',
    )
    parser.add_argument(
        '--filter',
        type=str,
        default='',
        help='Comma-separated list of image names to include',
    )
    parser.add_argument(
        '--output-format',
        choices=['json', 'matrix'],
        default='json',
        help='Output format (json array or GitHub Actions matrix)',
    )

    args = parser.parse_args()

    # Read SERVICE.MD
    if not args.service_md.exists():
        logger.error(f"SERVICE.MD not found at {args.service_md}")
        sys.exit(1)

    content = args.service_md.read_text()
    services = parse_service_table(content)

    logger.info(f"Parsed {len(services)} services from SERVICE.MD")

    # Apply filters
    if args.type != 'ALL':
        services = [s for s in services if s['type'] == args.type]
        logger.info(f"Filtered to {len(services)} {args.type} services")

    if args.buildable_only:
        services = [s for s in services if s['buildable']]
        logger.info(f"Filtered to {len(services)} buildable services")

    if args.filter:
        filter_list = [f.strip() for f in args.filter.split(',')]
        services = [s for s in services if s['image'] in filter_list]
        logger.info(f"Filtered to {len(services)} services matching filter")

    # Output
    if args.output_format == 'matrix':
        # GitHub Actions matrix format
        output = {
            'include': [
                {
                    'service': s['image'],
                    'path': s['path'] or '',
                    'type': s['type'],
                    'codename': s['codename'],
                }
                for s in services
            ]
        }
    else:
        output = services

    print(json.dumps(output, indent=2))


if __name__ == '__main__':
    main()
