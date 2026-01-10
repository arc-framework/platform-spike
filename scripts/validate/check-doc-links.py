#!/usr/bin/env python3
"""
A.R.C. Platform - Documentation Link Checker

Task: T061
Purpose: Verify all path references in documentation exist
Usage: python scripts/validate/check-doc-links.py [--strict] [--json]
Exit: 0=all pass, 1=broken links found
"""

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


@dataclass
class BrokenLink:
    """A broken link found in documentation."""
    source_file: str
    line: int
    link_text: str
    target_path: str
    link_type: str  # relative, absolute, anchor


@dataclass
class ValidationResult:
    """Result of link validation."""
    valid: bool
    files_checked: int = 0
    links_checked: int = 0
    broken_links: list[BrokenLink] = field(default_factory=list)


def find_repo_root() -> Path:
    """Find repository root."""
    current = Path(__file__).resolve()
    for parent in [current] + list(current.parents):
        if (parent / "SERVICE.MD").exists() or (parent / "Makefile").exists():
            return parent
    raise FileNotFoundError("Could not find repository root")


def find_markdown_files(repo_root: Path) -> list[Path]:
    """Find all markdown files in the repository."""
    md_files = []
    for md_file in repo_root.rglob("*.md"):
        # Skip node_modules, .git, vendor
        parts = md_file.parts
        if any(p in parts for p in ["node_modules", ".git", "vendor", "__pycache__"]):
            continue
        md_files.append(md_file)
    return sorted(md_files)


def extract_links(content: str) -> list[tuple[int, str, str]]:
    """Extract markdown links from content.

    Returns list of (line_number, link_text, target_path).
    """
    links = []
    lines = content.split("\n")

    for i, line in enumerate(lines, 1):
        # Standard markdown links: [text](path)
        for match in re.finditer(r'\[([^\]]+)\]\(([^)]+)\)', line):
            link_text = match.group(1)
            target = match.group(2)
            # Skip external URLs and anchors-only
            if not target.startswith(('http://', 'https://', 'mailto:', '#')):
                # Remove anchor from path
                target_path = target.split('#')[0]
                if target_path:
                    links.append((i, link_text, target_path))

        # Reference-style links: [text][ref] with [ref]: path
        # (simplified - full implementation would track references)

    return links


def resolve_link(source_file: Path, target: str, repo_root: Path) -> Path | None:
    """Resolve a link target to an absolute path."""
    # Handle relative paths
    if target.startswith('./') or target.startswith('../') or not target.startswith('/'):
        resolved = (source_file.parent / target).resolve()
    else:
        # Absolute path from repo root
        resolved = (repo_root / target.lstrip('/')).resolve()

    return resolved


def check_link_exists(resolved_path: Path, repo_root: Path) -> bool:
    """Check if a resolved link target exists."""
    # Check if it's within repo
    try:
        resolved_path.relative_to(repo_root)
    except ValueError:
        # Path is outside repo - might be valid, skip
        return True

    # Check if file or directory exists
    if resolved_path.exists():
        return True

    # Check if it might be a directory index
    if (resolved_path / "README.md").exists():
        return True
    if (resolved_path / "index.md").exists():
        return True

    # Check without extension for flexibility
    if resolved_path.with_suffix('.md').exists():
        return True

    return False


def validate_links(repo_root: Path) -> ValidationResult:
    """Validate all documentation links."""
    result = ValidationResult(valid=True)

    md_files = find_markdown_files(repo_root)
    result.files_checked = len(md_files)

    for md_file in md_files:
        try:
            content = md_file.read_text()
        except Exception:
            continue

        links = extract_links(content)
        result.links_checked += len(links)

        for line_num, link_text, target in links:
            resolved = resolve_link(md_file, target, repo_root)

            if resolved and not check_link_exists(resolved, repo_root):
                result.valid = False
                rel_source = str(md_file.relative_to(repo_root))

                # Determine link type
                if target.startswith('/'):
                    link_type = "absolute"
                elif target.startswith('./') or target.startswith('../'):
                    link_type = "relative"
                else:
                    link_type = "relative"

                result.broken_links.append(BrokenLink(
                    source_file=rel_source,
                    line=line_num,
                    link_text=link_text,
                    target_path=target,
                    link_type=link_type,
                ))

    return result


def output_text(result: ValidationResult) -> None:
    """Output results as text."""
    print("\033[0;36m╔═══════════════════════════════════════════════════════════════════╗\033[0m")
    print("\033[0;36m║          A.R.C. Documentation Link Checker                        ║\033[0m")
    print("\033[0;36m╚═══════════════════════════════════════════════════════════════════╝\033[0m")
    print()

    print(f"\033[0;34mFiles checked:\033[0m {result.files_checked}")
    print(f"\033[0;34mLinks checked:\033[0m {result.links_checked}")
    print()

    if not result.broken_links:
        print("\033[0;32m✅ All documentation links are valid!\033[0m")
        return

    print(f"\033[0;31m❌ Found {len(result.broken_links)} broken link(s):\033[0m")
    print()

    # Group by source file
    by_file: dict[str, list[BrokenLink]] = {}
    for link in result.broken_links:
        if link.source_file not in by_file:
            by_file[link.source_file] = []
        by_file[link.source_file].append(link)

    for source_file, links in sorted(by_file.items()):
        print(f"\033[0;33m{source_file}\033[0m")
        for link in links:
            print(f"  Line {link.line}: [{link.link_text}]({link.target_path})")
            print(f"           → Target not found")
        print()

    # Summary
    print("\033[0;36m═══════════════════════════════════════════════════════════════════\033[0m")
    print("\033[0;33mTo fix:\033[0m")
    print("  1. Create the missing file/directory")
    print("  2. Update the link to point to correct location")
    print("  3. Remove the link if content was deleted")


def output_json(result: ValidationResult) -> None:
    """Output results as JSON."""
    output: dict[str, Any] = {
        "valid": result.valid,
        "files_checked": result.files_checked,
        "links_checked": result.links_checked,
        "broken_links": [
            {
                "source_file": link.source_file,
                "line": link.line,
                "link_text": link.link_text,
                "target_path": link.target_path,
                "link_type": link.link_type,
            }
            for link in result.broken_links
        ],
    }
    print(json.dumps(output, indent=2))


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Check documentation links are valid"
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output results as JSON",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit with error on any broken link",
    )
    args = parser.parse_args()

    try:
        repo_root = find_repo_root()
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    result = validate_links(repo_root)

    if args.json:
        output_json(result)
    else:
        output_text(result)

    return 0 if result.valid else 1


if __name__ == "__main__":
    sys.exit(main())
