#!/usr/bin/env python3
"""
Generate GitHub Actions matrix from publish configuration files.

Reads JSON configuration files from .github/config/ and generates
matrix definitions for GitHub Actions workflows.

Usage:
    python generate-matrix.py --config publish-gateway.json
    python generate-matrix.py --config publish-data.json --platform linux/amd64
"""
import argparse
import json
import logging
import sys
from pathlib import Path

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)


def load_config(config_path: Path) -> dict:
    """Load and validate a publish configuration file."""
    if not config_path.exists():
        logger.error(f"Config file not found: {config_path}")
        sys.exit(1)

    with config_path.open() as f:
        config = json.load(f)

    # Validate required fields
    if 'images' not in config:
        logger.error(f"Config file missing 'images' key: {config_path}")
        sys.exit(1)

    return config


def generate_matrix(config: dict, platform_filter: str | None = None) -> dict:
    """Generate GitHub Actions matrix from config."""
    images = config.get('images', [])

    matrix_include = []
    for image in images:
        source = image.get('source', '')
        target = image.get('target', '')
        platforms = image.get('platforms', ['linux/amd64'])
        description = image.get('description', '')

        # Apply platform filter if specified
        if platform_filter and platform_filter not in platforms:
            continue

        # Create matrix entry
        matrix_include.append({
            'source': source,
            'target': target,
            'platforms': ','.join(platforms),
            'description': description,
        })

    return {
        'include': matrix_include,
        'metadata': {
            'image_count': len(matrix_include),
            'rate_limit_delay': config.get('rate_limit_delay_seconds', 30),
            'retry_attempts': config.get('retry_attempts', 3),
            'timeout_minutes': config.get('timeout_minutes', 10),
        }
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        '--config',
        type=str,
        required=True,
        help='Config file name (e.g., publish-gateway.json)',
    )
    parser.add_argument(
        '--config-dir',
        type=Path,
        default=Path('.github/config'),
        help='Directory containing config files',
    )
    parser.add_argument(
        '--platform',
        type=str,
        default=None,
        help='Filter to specific platform (e.g., linux/amd64)',
    )
    parser.add_argument(
        '--output',
        choices=['matrix', 'images', 'count'],
        default='matrix',
        help='Output type',
    )

    args = parser.parse_args()

    config_path = args.config_dir / args.config
    config = load_config(config_path)

    logger.info(f"Loaded config from {config_path}")
    logger.info(f"Found {len(config.get('images', []))} images")

    matrix = generate_matrix(config, args.platform)

    if args.output == 'matrix':
        # Output full matrix for GitHub Actions
        print(json.dumps(matrix, indent=2))
    elif args.output == 'images':
        # Output just the image list
        print(json.dumps(matrix['include'], indent=2))
    elif args.output == 'count':
        # Output just the count
        print(matrix['metadata']['image_count'])


if __name__ == '__main__':
    main()
