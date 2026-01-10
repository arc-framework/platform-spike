#!/usr/bin/env python3
"""
A.R.C. Platform - Docker Image Size Validator

Task: T048
Purpose: Validate Docker image sizes against Constitution targets
Usage: python scripts/validate/check-image-sizes.py [--json] [--strict]
Exit: 0=all pass, 1=size violations found
"""

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


# Size limits from Constitution (in bytes)
SIZE_LIMITS = {
    # Python services - max 500MB
    "python": 500 * 1024 * 1024,
    # Go services - max 50MB
    "go": 50 * 1024 * 1024,
    # Base images
    "base-python": 300 * 1024 * 1024,
    "base-go": 50 * 1024 * 1024,
    # Infrastructure (upstream images, more lenient)
    "infra": 200 * 1024 * 1024,
}

# Service to language mapping
SERVICE_LANGUAGES = {
    "arc-sherlock-brain": "python",
    "arc-scarlett-voice": "python",
    "arc-piper-tts": "python",
    "raymond": "go",
    "arc-base-python-ai": "base-python",
    "arc-base-go-infra": "base-go",
}


@dataclass
class ImageInfo:
    """Docker image information."""
    repository: str
    tag: str
    size_bytes: int
    size_human: str
    language: str
    limit_bytes: int
    passes: bool


def parse_size(size_str: str) -> int:
    """Parse Docker size string (e.g., '150MB', '1.2GB') to bytes."""
    size_str = size_str.strip().upper()

    multipliers = {
        "B": 1,
        "KB": 1024,
        "MB": 1024 * 1024,
        "GB": 1024 * 1024 * 1024,
    }

    for suffix, multiplier in multipliers.items():
        if size_str.endswith(suffix):
            try:
                value = float(size_str[:-len(suffix)])
                return int(value * multiplier)
            except ValueError:
                pass

    return 0


def format_size(size_bytes: int) -> str:
    """Format bytes as human-readable size."""
    for unit in ["B", "KB", "MB", "GB"]:
        if size_bytes < 1024:
            return f"{size_bytes:.1f}{unit}"
        size_bytes /= 1024
    return f"{size_bytes:.1f}TB"


def get_docker_images() -> list[dict[str, str]]:
    """Get list of arc-* Docker images."""
    try:
        result = subprocess.run(
            [
                "docker", "images",
                "--format", "{{.Repository}}\t{{.Tag}}\t{{.Size}}",
            ],
            capture_output=True,
            text=True,
            check=True,
        )

        images = []
        for line in result.stdout.strip().split("\n"):
            if not line:
                continue
            parts = line.split("\t")
            if len(parts) >= 3:
                repo = parts[0]
                # Filter for arc-* images
                if repo.startswith("arc-") or "arc" in repo.lower():
                    images.append({
                        "repository": repo,
                        "tag": parts[1],
                        "size": parts[2],
                    })

        return images
    except subprocess.CalledProcessError:
        return []


def detect_language(repo: str) -> str:
    """Detect language/type for a repository name."""
    # Check explicit mapping first
    for service, lang in SERVICE_LANGUAGES.items():
        if service in repo:
            return lang

    # Heuristics based on name
    if "python" in repo.lower() or "py" in repo.lower():
        return "python"
    if "go" in repo.lower() or "golang" in repo.lower():
        return "go"
    if "base" in repo.lower():
        return "base-python"  # Default base to python

    # Default to python (most common in A.R.C.)
    return "python"


def check_image_sizes(images: list[dict[str, str]]) -> list[ImageInfo]:
    """Check image sizes against limits."""
    results = []

    for image in images:
        repo = image["repository"]
        tag = image["tag"]
        size_bytes = parse_size(image["size"])

        language = detect_language(repo)
        limit = SIZE_LIMITS.get(language, SIZE_LIMITS["python"])
        passes = size_bytes <= limit

        results.append(ImageInfo(
            repository=repo,
            tag=tag,
            size_bytes=size_bytes,
            size_human=image["size"],
            language=language,
            limit_bytes=limit,
            passes=passes,
        ))

    return results


def output_text(results: list[ImageInfo], strict: bool) -> int:
    """Output results as text."""
    print("\033[0;36m╔═══════════════════════════════════════════════════════════════════╗\033[0m")
    print("\033[0;36m║          A.R.C. Image Size Validator                              ║\033[0m")
    print("\033[0;36m╚═══════════════════════════════════════════════════════════════════╝\033[0m")
    print()

    if not results:
        print("\033[0;33m⚠️  No arc-* images found. Build images first.\033[0m")
        print()
        print("Build commands:")
        print("  make build-base-images")
        print("  docker build -t arc-sherlock-brain:local services/arc-sherlock-brain/")
        return 0

    # Group by pass/fail
    passed = [r for r in results if r.passes]
    failed = [r for r in results if not r.passes]

    # Print results
    print(f"\033[0;34mImages checked:\033[0m {len(results)}")
    print()

    # Size limits reference
    print("\033[0;36mSize Limits (from Constitution):\033[0m")
    print(f"  Python services: {format_size(SIZE_LIMITS['python'])}")
    print(f"  Go services:     {format_size(SIZE_LIMITS['go'])}")
    print(f"  Base images:     {format_size(SIZE_LIMITS['base-python'])}")
    print()

    # Results table
    print("\033[0;36m═══════════════════════════════════════════════════════════════════\033[0m")
    print(f"{'Image':<40} {'Size':<12} {'Limit':<12} {'Status':<10}")
    print("\033[0;36m───────────────────────────────────────────────────────────────────\033[0m")

    for result in sorted(results, key=lambda r: r.repository):
        status = "\033[0;32m✓ PASS\033[0m" if result.passes else "\033[0;31m✗ FAIL\033[0m"
        image_name = f"{result.repository}:{result.tag}"
        if len(image_name) > 38:
            image_name = image_name[:35] + "..."

        print(f"{image_name:<40} {result.size_human:<12} {format_size(result.limit_bytes):<12} {status}")

    print("\033[0;36m═══════════════════════════════════════════════════════════════════\033[0m")
    print()

    # Summary
    print("\033[0;36mSummary:\033[0m")
    print(f"  \033[0;32m✓ Passed:\033[0m {len(passed)}")
    print(f"  \033[0;31m✗ Failed:\033[0m {len(failed)}")
    print()

    if failed:
        print("\033[0;33mRemediation:\033[0m")
        print("  1. Use multi-stage builds to separate build and runtime")
        print("  2. Remove unnecessary packages from runtime stage")
        print("  3. Use Alpine-based images for smaller size")
        print("  4. Review .dockerignore to exclude build artifacts")
        print()

    return 1 if (failed and strict) else 0


def output_json(results: list[ImageInfo]) -> int:
    """Output results as JSON."""
    output: dict[str, Any] = {
        "timestamp": subprocess.run(
            ["date", "-u", "+%Y-%m-%dT%H:%M:%SZ"],
            capture_output=True, text=True
        ).stdout.strip(),
        "limits": {k: v for k, v in SIZE_LIMITS.items()},
        "images": [],
        "summary": {
            "total": len(results),
            "passed": sum(1 for r in results if r.passes),
            "failed": sum(1 for r in results if not r.passes),
        },
    }

    for result in results:
        output["images"].append({
            "repository": result.repository,
            "tag": result.tag,
            "size_bytes": result.size_bytes,
            "size_human": result.size_human,
            "language": result.language,
            "limit_bytes": result.limit_bytes,
            "passes": result.passes,
        })

    print(json.dumps(output, indent=2))

    return 1 if output["summary"]["failed"] > 0 else 0


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Validate Docker image sizes against Constitution targets"
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output results as JSON",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit with error if any image exceeds limit",
    )
    args = parser.parse_args()

    # Get Docker images
    images = get_docker_images()

    # Check sizes
    results = check_image_sizes(images)

    # Output
    if args.json:
        return output_json(results)
    else:
        return output_text(results, args.strict)


if __name__ == "__main__":
    sys.exit(main())
