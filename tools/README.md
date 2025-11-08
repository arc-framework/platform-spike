# Development Tools

Automation scripts for operations, setup, and development tasks.

---

## ⚠️ Note: Tool Scripts Have Moved

Analysis and journal scripts have been moved to their respective tool directories:
- **Analysis scripts** → `tools/analysis/` (see [tools/analysis](../tools/analysis/))
- **Journal scripts** → `tools/journal/` (see [tools/journal](../tools/journal/))

This directory now contains operational and infrastructure scripts only.

---

**Scripts:**
- `run-analysis.sh` - Generate comprehensive analysis
- `test-analysis-system.sh` - Verify analysis system

## Tools Overview

- Code organization and structure
- Configuration management
- Security best practices
- Documentation completeness

**Documentation**: [Analysis README](./analysis/README.md)

### Journal System
**Location**: `tools/journal/`  
**Scripts:**
- `generate-journal.sh` - Generate daily journal entry

**Purpose**: Track project evolution and technical decisions

Automated journal generation from git history:
- Daily development logs
- Technical decision tracking
- Project milestone documentation

---

**Documentation**: [Journal README](./journal/README.md)

### Prompt Templates
**Location**: `tools/prompts/`  
./scripts/setup/init-project.sh
./scripts/operations/backup.sh

Templates for:
Most operational tasks are available via Makefile:
- Journal entry formatting (`template-journal.md`)

**Documentation**: [Prompts README](./prompts/README.md)
make backup

./tools/analysis/run-analysis.sh
---
## Other Development Tools
./tools/journal/generate-journal.sh
- **generators/** - Code generation utilities
1. **Operational scripts** → `scripts/operations/`
2. **Setup scripts** → `scripts/setup/`
3. **Development helpers** → `scripts/development/`
4. **Tool-specific scripts** → `tools/<tool-name>/`

### Guidelines
1. Make executable: `chmod +x scripts/category/script.sh`
2. Add Makefile target if commonly used
3. Document in this README
4. Follow naming conventions (see [docs/guides/NAMING-CONVENTIONS.md](../docs/guides/NAMING-CONVENTIONS.md))

---

## See Also

- [Tools](../tools/) - Development and analysis tools
- [Operations Guide](../docs/OPERATIONS.md) - Operational procedures
- [Makefile](../Makefile) - Orchestration commands
All tools are designed to be run from the project root:

```bash
# Analysis
./scripts/analysis/run-analysis.sh

# Journal
./scripts/operations/generate-journal.sh
```

## Generated Content

- **Reports**: See [../reports/](../reports/) for generated analysis reports
- **Journal Entries**: See [journal/entries/](./journal/entries/) for daily journals

## See Also

- [Scripts](../scripts/) - Automation and orchestration scripts
- [Documentation](../docs/) - Framework documentation

