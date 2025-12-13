# Scripts

Lightweight shell tooling that supports project setup. Historical script collections were migrated to other directories; this README tracks the active surface.

## Current Structure

- `setup/` – Secret generation and validation helpers for initializing `.env`
- `show-roster.sh` – Display all running A.R.C. services with codenames and roles
- `inspect-service.sh` – Inspect Docker labels for a specific service
- `verify-labels.sh` – Verify all services have complete label metadata

Legacy automation now lives in:

- `tools/analysis/` – Repository analysis pipeline (replaces the old `scripts/analysis/` folder)
- `tools/journal/` – Daily journal generator (supersedes the former operations scripts)

## Usage

### Setup & Validation

Run setup utilities from the project root:

```bash
./scripts/setup/generate-secrets.sh
./scripts/setup/validate-secrets.sh
```

### Service Management

View your running superhero lineup:

```bash
./scripts/show-roster.sh
# or via Makefile:
make roster
```

Inspect a specific service's labels:

```bash
./scripts/inspect-service.sh oracle
./scripts/inspect-service.sh arc-daredevil-voice
```

Verify all services have complete labels:

```bash
./scripts/verify-labels.sh
# or via Makefile:
make validate-labels
Run setup utilities from the project root:

```bash
./scripts/setup/generate-secrets.sh
./scripts/setup/validate-secrets.sh
```

Many tasks are also exposed through the Makefile:

```bash
make generate-secrets
make validate-secrets
make roster
make validate-labels
```

## Adding New Scripts

1. Create a subdirectory under `scripts/` that matches the script purpose (for example, `scripts/maintenance/`).
2. Make scripts executable: `chmod +x scripts/<dir>/<script>.sh`.
3. Document invocation and prerequisites in this README.
4. Expose common workflows through the Makefile when practical.
