#!/usr/bin/env python3
"""
A.R.C. Platform - Docker Image Dependency Analyzer

Purpose: Analyze Docker image dependency tree and generate visualizations
Usage: python scripts/validate/analyze-dependencies.py [--output FORMAT]
Exit: 0=success, 1=error
"""

import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any


def find_dockerfiles(repo_root: Path) -> list[Path]:
    """Find all Dockerfiles in the repository."""
    dockerfiles = []
    for dockerfile in repo_root.rglob("Dockerfile"):
        parts = dockerfile.parts
        if any(p in parts for p in ["node_modules", ".git", "vendor"]):
            continue
        dockerfiles.append(dockerfile)
    return sorted(dockerfiles)


def parse_dockerfile(dockerfile: Path) -> dict[str, Any]:
    """Parse a Dockerfile and extract FROM statements and metadata."""
    content = dockerfile.read_text()
    lines = content.split("\n")

    result = {
        "path": str(dockerfile),
        "stages": [],
        "final_base": None,
        "labels": {},
    }

    current_stage = None

    for line in lines:
        line = line.strip()

        # Parse FROM statements
        from_match = re.match(
            r"^FROM\s+([^\s]+)(?:\s+AS\s+(\w+))?", line, re.IGNORECASE
        )
        if from_match:
            image = from_match.group(1)
            stage_name = from_match.group(2)

            stage = {
                "image": image,
                "name": stage_name,
                "is_builder": stage_name and "build" in stage_name.lower(),
            }
            result["stages"].append(stage)
            current_stage = stage

        # Parse LABEL statements
        label_match = re.match(r'^LABEL\s+(.+)$', line, re.IGNORECASE)
        if label_match:
            label_content = label_match.group(1)
            # Simple parsing - handles key="value" format
            for match in re.finditer(r'(\S+)=["\']?([^"\']+)["\']?', label_content):
                result["labels"][match.group(1)] = match.group(2)

    # Final base is the last non-builder stage's image
    for stage in reversed(result["stages"]):
        if not stage["is_builder"]:
            result["final_base"] = stage["image"]
            break

    if not result["final_base"] and result["stages"]:
        result["final_base"] = result["stages"][-1]["image"]

    return result


def get_service_name(dockerfile_path: Path, repo_root: Path) -> str:
    """Extract service name from Dockerfile path."""
    rel_path = dockerfile_path.relative_to(repo_root)
    parts = rel_path.parts

    # Handle different directory structures
    if "services" in parts:
        idx = parts.index("services")
        if idx + 1 < len(parts) - 1:
            return parts[idx + 1]
    elif ".docker" in parts and "base" in parts:
        idx = parts.index("base")
        if idx + 1 < len(parts) - 1:
            return f"base-{parts[idx + 1]}"
    elif "core" in parts:
        # core/category/service/Dockerfile
        idx = parts.index("core")
        if idx + 2 < len(parts) - 1:
            return f"core-{parts[idx + 2]}"
    elif "plugins" in parts:
        idx = parts.index("plugins")
        if idx + 2 < len(parts) - 1:
            return f"plugin-{parts[idx + 2]}"

    # Fallback: use parent directory name
    return dockerfile_path.parent.name


def normalize_image_name(image: str) -> str:
    """Normalize image name for comparison."""
    # Remove tag
    if ":" in image:
        image = image.split(":")[0]
    # Remove registry prefix for local images
    if "/" in image:
        parts = image.split("/")
        if parts[0] in ["ghcr.io", "docker.io", "gcr.io"]:
            image = "/".join(parts[1:])
    return image


def build_dependency_graph(
    repo_root: Path,
) -> dict[str, Any]:
    """Build dependency graph from all Dockerfiles."""
    dockerfiles = find_dockerfiles(repo_root)

    graph = {
        "nodes": {},  # service_name -> {path, base_image, labels}
        "edges": [],  # [{from, to, type}]
        "base_images": defaultdict(list),  # base_image -> [dependent_services]
    }

    # First pass: collect all services and their base images
    for dockerfile in dockerfiles:
        parsed = parse_dockerfile(dockerfile)
        service_name = get_service_name(dockerfile, repo_root)

        graph["nodes"][service_name] = {
            "path": str(dockerfile.relative_to(repo_root)),
            "base_image": parsed["final_base"],
            "stages": len(parsed["stages"]),
            "labels": parsed["labels"],
        }

        if parsed["final_base"]:
            normalized_base = normalize_image_name(parsed["final_base"])
            graph["base_images"][normalized_base].append(service_name)

    # Second pass: build edges
    # Check if any service's base image is another service in the repo
    for service_name, info in graph["nodes"].items():
        base = info["base_image"]
        if not base:
            continue

        normalized_base = normalize_image_name(base)

        # Check if base is an internal image
        for other_service, other_info in graph["nodes"].items():
            if other_service == service_name:
                continue

            # Check if this service's base matches another service
            if normalized_base.endswith(other_service) or other_service in normalized_base:
                graph["edges"].append({
                    "from": other_service,
                    "to": service_name,
                    "type": "depends_on",
                })

        # Also check for arc base images
        if "arc" in normalized_base.lower() or "base" in normalized_base.lower():
            for base_service in graph["nodes"]:
                if base_service.startswith("base-"):
                    base_name = base_service.replace("base-", "")
                    if base_name in normalized_base:
                        graph["edges"].append({
                            "from": base_service,
                            "to": service_name,
                            "type": "depends_on",
                        })

    return graph


def output_json(graph: dict[str, Any]) -> str:
    """Output graph as JSON."""
    return json.dumps(graph, indent=2)


def output_mermaid(graph: dict[str, Any]) -> str:
    """Output graph as Mermaid diagram."""
    lines = ["graph TD"]

    # Add nodes with styling
    for service, info in graph["nodes"].items():
        label = service.replace("-", "_")
        if service.startswith("base-"):
            lines.append(f"    {label}[({service})]:::base")
        elif service.startswith("core-"):
            lines.append(f"    {label}[{service}]:::core")
        elif service.startswith("plugin-"):
            lines.append(f"    {label}[{service}]:::plugin")
        else:
            lines.append(f"    {label}[{service}]:::service")

    lines.append("")

    # Add edges
    for edge in graph["edges"]:
        from_label = edge["from"].replace("-", "_")
        to_label = edge["to"].replace("-", "_")
        lines.append(f"    {from_label} --> {to_label}")

    lines.append("")

    # Add styling
    lines.extend([
        "    classDef base fill:#f9f,stroke:#333,stroke-width:2px",
        "    classDef core fill:#bbf,stroke:#333,stroke-width:2px",
        "    classDef plugin fill:#bfb,stroke:#333,stroke-width:2px",
        "    classDef service fill:#fbb,stroke:#333,stroke-width:2px",
    ])

    return "\n".join(lines)


def output_tree(graph: dict[str, Any]) -> str:
    """Output graph as ASCII tree."""
    lines = ["Docker Image Dependency Tree", "=" * 40, ""]

    # Group by base image
    base_to_services = defaultdict(list)
    for service, info in graph["nodes"].items():
        base = info.get("base_image", "unknown")
        base_to_services[base].append(service)

    for base, services in sorted(base_to_services.items()):
        lines.append(f"📦 {base}")
        for i, service in enumerate(sorted(services)):
            prefix = "└──" if i == len(services) - 1 else "├──"
            lines.append(f"   {prefix} {service}")
        lines.append("")

    return "\n".join(lines)


def output_impact(graph: dict[str, Any], changed_service: str) -> str:
    """Output impact analysis for a changed service."""
    lines = [f"Impact Analysis: {changed_service}", "=" * 40, ""]

    # Find all services that depend on the changed service
    affected = set()

    def find_dependents(service: str, visited: set) -> None:
        if service in visited:
            return
        visited.add(service)
        for edge in graph["edges"]:
            if edge["from"] == service:
                affected.add(edge["to"])
                find_dependents(edge["to"], visited)

    find_dependents(changed_service, set())

    if affected:
        lines.append("Services that need rebuilding:")
        for service in sorted(affected):
            lines.append(f"  • {service}")
    else:
        lines.append("No dependent services found.")

    lines.append("")
    lines.append(f"Total affected: {len(affected)} service(s)")

    return "\n".join(lines)


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Analyze Docker image dependencies"
    )
    parser.add_argument(
        "--output", "-o",
        choices=["json", "mermaid", "tree", "impact"],
        default="tree",
        help="Output format (default: tree)"
    )
    parser.add_argument(
        "--service", "-s",
        help="Service name for impact analysis"
    )
    parser.add_argument(
        "--file", "-f",
        type=Path,
        help="Output to file instead of stdout"
    )
    args = parser.parse_args()

    # Find repository root
    script_path = Path(__file__).resolve()
    repo_root = script_path.parent.parent.parent

    # Build dependency graph
    print("🔍 Analyzing Dockerfiles...", file=sys.stderr)
    graph = build_dependency_graph(repo_root)
    print(f"Found {len(graph['nodes'])} services", file=sys.stderr)

    # Generate output
    if args.output == "json":
        output = output_json(graph)
    elif args.output == "mermaid":
        output = output_mermaid(graph)
    elif args.output == "impact":
        if not args.service:
            print("Error: --service required for impact analysis", file=sys.stderr)
            return 1
        output = output_impact(graph, args.service)
    else:
        output = output_tree(graph)

    # Output
    if args.file:
        args.file.parent.mkdir(parents=True, exist_ok=True)
        args.file.write_text(output)
        print(f"📄 Output saved to: {args.file}", file=sys.stderr)
    else:
        print(output)

    return 0


if __name__ == "__main__":
    sys.exit(main())
