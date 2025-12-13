# Services

Application workloads that run on top of the A.R.C. Framework.

---

## Current Structure

Only one service lives in this directory today and it serves as the reference implementation for future workloads.

```
services/
└── utilities/
    └── toolbox/           # Go-based utility container with helper tooling
```

### `utilities/toolbox`

- Multi-purpose Go binary packaged as `toolbox`
- Provides operational helpers and ad-hoc automation
- Inspect the source in `services/utilities/toolbox/` for usage details

---

## Adding New Services

When you introduce additional workloads:

- Create a new subdirectory under `services/`
- Include a concise `README.md` describing the service purpose and runtime requirements
- Add language-specific manifests (`go.mod`, `pyproject.toml`, `package.json`, etc.)
- Follow the naming conventions in `docs/guides/NAMING-CONVENTIONS.md`

---

## Related Documentation

- [Core Services](../core/) – foundational infrastructure
- [Plugins](../plugins/) – optional and swappable components
- [Naming Conventions](../docs/guides/NAMING-CONVENTIONS.md) – directory and service naming standards
