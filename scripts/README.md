# Scripts

Lightweight shell tooling that supports project setup. Historical script collections were migrated to other directories; this README tracks the active surface.

## Current Structure

- `setup/` – Secret generation and validation helpers for initializing `.env`

Legacy automation now lives in:

- `tools/analysis/` – Repository analysis pipeline (replaces the old `scripts/analysis/` folder)
- `tools/journal/` – Daily journal generator (supersedes the former operations scripts)

## Usage

Run setup utilities from the project root:

```bash
./scripts/setup/generate-secrets.sh
./scripts/setup/validate-secrets.sh
```

Many tasks are also exposed through the Makefile:

```bash
make generate-secrets
make validate-secrets
```

## Adding New Scripts

1. Create a subdirectory under `scripts/` that matches the script purpose (for example, `scripts/maintenance/`).
2. Make scripts executable: `chmod +x scripts/<dir>/<script>.sh`.
3. Document invocation and prerequisites in this README.
4. Expose common workflows through the Makefile when practical.
