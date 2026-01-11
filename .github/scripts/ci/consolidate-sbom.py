#!/usr/bin/env python3
"""
Consolidate multiple SBOM files into a single report.

Parses SPDX JSON SBOM files and generates a consolidated CSV report
with all dependencies across all services.

Usage:
    python consolidate-sbom.py --input sbom/ --output report.csv
    python consolidate-sbom.py --input sbom/ --output report.csv --format json

Output columns:
    service, package, version, license, purl, supplier
"""
import argparse
import csv
import json
import logging
import sys
from dataclasses import dataclass, asdict
from pathlib import Path

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)


@dataclass
class Dependency:
    """Represents a software dependency."""
    service: str
    package: str
    version: str
    license: str
    purl: str
    supplier: str
    type: str  # npm, pip, apk, etc.


def parse_spdx_sbom(sbom_path: Path, service_name: str) -> list[Dependency]:
    """Parse an SPDX JSON SBOM file."""
    dependencies = []

    try:
        with open(sbom_path) as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        logger.warning(f"Failed to parse {sbom_path}: {e}")
        return []

    # SPDX format has packages array
    packages = data.get('packages', [])

    for pkg in packages:
        # Skip the root document package
        if pkg.get('SPDXID') == 'SPDXRef-DOCUMENT':
            continue

        name = pkg.get('name', 'unknown')
        version = pkg.get('versionInfo', 'unknown')

        # Extract license
        license_info = pkg.get('licenseConcluded', 'NOASSERTION')
        if license_info == 'NOASSERTION':
            license_info = pkg.get('licenseDeclared', 'Unknown')

        # Extract PURL (Package URL)
        purl = ''
        for ref in pkg.get('externalRefs', []):
            if ref.get('referenceType') == 'purl':
                purl = ref.get('referenceLocator', '')
                break

        # Extract supplier
        supplier = pkg.get('supplier', 'Unknown')
        if isinstance(supplier, str) and supplier.startswith('Organization:'):
            supplier = supplier.replace('Organization:', '').strip()

        # Determine package type from PURL or name
        pkg_type = 'unknown'
        if 'pkg:pypi' in purl:
            pkg_type = 'pip'
        elif 'pkg:npm' in purl:
            pkg_type = 'npm'
        elif 'pkg:apk' in purl:
            pkg_type = 'apk'
        elif 'pkg:deb' in purl:
            pkg_type = 'deb'
        elif 'pkg:golang' in purl:
            pkg_type = 'go'

        dep = Dependency(
            service=service_name,
            package=name,
            version=version,
            license=license_info,
            purl=purl,
            supplier=supplier,
            type=pkg_type,
        )
        dependencies.append(dep)

    return dependencies


def parse_cyclonedx_sbom(sbom_path: Path, service_name: str) -> list[Dependency]:
    """Parse a CycloneDX JSON SBOM file."""
    dependencies = []

    try:
        with open(sbom_path) as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        logger.warning(f"Failed to parse {sbom_path}: {e}")
        return []

    # CycloneDX format has components array
    components = data.get('components', [])

    for comp in components:
        name = comp.get('name', 'unknown')
        version = comp.get('version', 'unknown')

        # Extract license
        licenses = comp.get('licenses', [])
        license_info = 'Unknown'
        if licenses:
            first_license = licenses[0]
            if 'license' in first_license:
                license_info = first_license['license'].get('id', first_license['license'].get('name', 'Unknown'))
            elif 'expression' in first_license:
                license_info = first_license['expression']

        # Extract PURL
        purl = comp.get('purl', '')

        # Extract supplier/publisher
        supplier = comp.get('publisher', comp.get('author', 'Unknown'))

        # Determine package type
        pkg_type = comp.get('type', 'library')
        if 'pkg:pypi' in purl:
            pkg_type = 'pip'
        elif 'pkg:npm' in purl:
            pkg_type = 'npm'

        dep = Dependency(
            service=service_name,
            package=name,
            version=version,
            license=license_info,
            purl=purl,
            supplier=supplier,
            type=pkg_type,
        )
        dependencies.append(dep)

    return dependencies


def find_sbom_files(input_dir: Path) -> list[tuple[Path, str]]:
    """Find all SBOM files and their associated service names."""
    sbom_files = []

    # Look for SPDX files
    for sbom_file in input_dir.glob('**/*.spdx.json'):
        # Extract service name from path or filename
        service_name = sbom_file.parent.name
        if service_name in ('.', 'sbom', 'artifacts'):
            service_name = sbom_file.stem.replace('.spdx', '')
        sbom_files.append((sbom_file, service_name))

    # Look for CycloneDX files
    for sbom_file in input_dir.glob('**/*.cdx.json'):
        service_name = sbom_file.parent.name
        if service_name in ('.', 'sbom', 'artifacts'):
            service_name = sbom_file.stem.replace('.cdx', '')
        sbom_files.append((sbom_file, service_name))

    # Look for generic SBOM files
    for sbom_file in input_dir.glob('**/sbom*.json'):
        if '.spdx.' not in sbom_file.name and '.cdx.' not in sbom_file.name:
            service_name = sbom_file.parent.name
            sbom_files.append((sbom_file, service_name))

    return sbom_files


def consolidate_sboms(input_dir: Path) -> list[Dependency]:
    """Consolidate all SBOM files in a directory."""
    all_dependencies = []

    sbom_files = find_sbom_files(input_dir)
    logger.info(f"Found {len(sbom_files)} SBOM files")

    for sbom_path, service_name in sbom_files:
        logger.info(f"Processing: {sbom_path} (service: {service_name})")

        # Try to detect format
        try:
            with open(sbom_path) as f:
                data = json.load(f)

            if 'spdxVersion' in data:
                deps = parse_spdx_sbom(sbom_path, service_name)
            elif 'bomFormat' in data and data['bomFormat'] == 'CycloneDX':
                deps = parse_cyclonedx_sbom(sbom_path, service_name)
            else:
                logger.warning(f"Unknown SBOM format: {sbom_path}")
                continue

            all_dependencies.extend(deps)
            logger.info(f"  Found {len(deps)} dependencies")

        except Exception as e:
            logger.error(f"Failed to process {sbom_path}: {e}")

    return all_dependencies


def write_csv_report(dependencies: list[Dependency], output_path: Path):
    """Write dependencies to CSV file."""
    with open(output_path, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=[
            'service', 'package', 'version', 'license', 'type', 'purl', 'supplier'
        ])
        writer.writeheader()

        for dep in dependencies:
            writer.writerow(asdict(dep))

    logger.info(f"Wrote {len(dependencies)} dependencies to {output_path}")


def write_json_report(dependencies: list[Dependency], output_path: Path):
    """Write dependencies to JSON file."""
    data = {
        'total_dependencies': len(dependencies),
        'services': list(set(d.service for d in dependencies)),
        'dependencies': [asdict(d) for d in dependencies],
    }

    with open(output_path, 'w') as f:
        json.dump(data, f, indent=2)

    logger.info(f"Wrote {len(dependencies)} dependencies to {output_path}")


def generate_summary(dependencies: list[Dependency]) -> dict:
    """Generate summary statistics."""
    services = set(d.service for d in dependencies)
    packages = set(d.package for d in dependencies)
    licenses = {}

    for dep in dependencies:
        license_key = dep.license if dep.license else 'Unknown'
        licenses[license_key] = licenses.get(license_key, 0) + 1

    # Sort licenses by count
    sorted_licenses = sorted(licenses.items(), key=lambda x: x[1], reverse=True)

    return {
        'total_dependencies': len(dependencies),
        'unique_packages': len(packages),
        'services_analyzed': len(services),
        'services': list(services),
        'top_licenses': sorted_licenses[:10],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        '--input',
        type=Path,
        required=True,
        help='Directory containing SBOM files',
    )
    parser.add_argument(
        '--output',
        type=Path,
        required=True,
        help='Output file path',
    )
    parser.add_argument(
        '--format',
        choices=['csv', 'json'],
        default='csv',
        help='Output format (default: csv)',
    )
    parser.add_argument(
        '--summary',
        action='store_true',
        help='Print summary to stdout',
    )

    args = parser.parse_args()

    if not args.input.exists():
        logger.error(f"Input directory not found: {args.input}")
        sys.exit(1)

    # Consolidate SBOMs
    dependencies = consolidate_sboms(args.input)

    if not dependencies:
        logger.warning("No dependencies found in SBOM files")
        # Create empty output
        if args.format == 'csv':
            write_csv_report([], args.output)
        else:
            write_json_report([], args.output)
        return

    # Write output
    if args.format == 'csv':
        write_csv_report(dependencies, args.output)
    else:
        write_json_report(dependencies, args.output)

    # Print summary if requested
    if args.summary:
        summary = generate_summary(dependencies)
        print("\n=== SBOM Consolidation Summary ===")
        print(f"Total dependencies: {summary['total_dependencies']}")
        print(f"Unique packages: {summary['unique_packages']}")
        print(f"Services analyzed: {summary['services_analyzed']}")
        print(f"Services: {', '.join(summary['services'])}")
        print("\nTop licenses:")
        for license_name, count in summary['top_licenses']:
            print(f"  {license_name}: {count}")


if __name__ == '__main__':
    main()
