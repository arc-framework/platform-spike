# Development Tools

Supporting utilities that augment the Makefile for analysis, journaling, and content generation.

---

## Analysis Toolkit

**Location:** `tools/analysis/`

- `run-analysis.sh` – Generates the comprehensive repository reports stored under `reports/`
- `README.md` – Detailed usage, CLI flags, and automation guidance

Run from the project root:

```bash
./tools/analysis/run-analysis.sh
```

---

## Journal System

**Location:** `tools/journal/`

- `generate-journal.sh` – Produces daily engineering journal entries in `tools/journal/entries/`
- `README.md` – Scheduling, template customization, and operational tips

Example:

```bash
./tools/journal/generate-journal.sh --help
```

---

## Prompt Templates

**Location:** `tools/prompts/`

- `template-analysis.md` – Standard analysis prompt template
- `template-journal.md` – Journal entry prompt template
- `README.md` – How the templates integrate with the tooling

---

## Contribution Guidelines

1. Keep tool-specific scripts within their tool directory (e.g., `tools/<name>/`).
2. Make executables runnable via `chmod +x` and document invocation examples.
3. Consider adding Makefile targets for frequently used tooling.
4. Follow naming guidance in [docs/guides/NAMING-CONVENTIONS.md](../docs/guides/NAMING-CONVENTIONS.md).

---

## Related Resources

- [Scripts](../scripts/) – Legacy automation entry points
- [Operations Guide](../docs/OPERATIONS.md) – Day-to-day operational procedures
- [Makefile](../Makefile) – Primary orchestration surface
- [Reports](../reports/) – Generated analysis artifacts
- [tools/journal/entries/](./journal/entries/) – Historical journal output
