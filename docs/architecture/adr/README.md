# Architecture Decision Records (ADRs)

This directory contains Architecture Decision Records for the A.R.C. platform.

## What is an ADR?

An Architecture Decision Record (ADR) is a document that captures an important architectural decision made along with its context and consequences.

## ADR Index

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [ADR-000](./000-template.md) | Template | Template | - |
| [ADR-001](./001-codename-convention.md) | Codename Convention | Accepted | 2025-11 |
| [ADR-002](./002-three-tier-structure.md) | Three-Tier Directory Structure | Accepted | 2026-01 |

## Creating a New ADR

1. Copy the template:
   ```bash
   cp docs/architecture/adr/000-template.md docs/architecture/adr/XXX-my-decision.md
   ```

2. Fill in all sections

3. Submit for review

4. Update this index when accepted

## ADR Lifecycle

```
Proposed → Accepted → [Deprecated | Superseded]
```

- **Proposed**: Under discussion
- **Accepted**: Decision made and implemented
- **Deprecated**: No longer relevant
- **Superseded**: Replaced by another ADR

## Best Practices

1. **Keep ADRs small**: One decision per ADR
2. **Be specific**: Include concrete examples
3. **Document alternatives**: Show what was considered
4. **Update, don't delete**: Mark old ADRs as deprecated/superseded
5. **Link related ADRs**: Cross-reference when relevant
