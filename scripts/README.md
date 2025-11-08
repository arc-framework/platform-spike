# Scripts

Automation scripts organized by purpose.

## Structure

### analysis/
Repository analysis and health checking:
- `run-analysis.sh` - Generate and run repository analysis
- `test-analysis-system.sh` - Verify analysis system is working

### setup/
Initial setup and dependency installation:
- `init-project.sh` - Initialize project (planned)
- `install-dependencies.sh` - Install required tools (planned)

### operations/
Operational maintenance scripts:
- `backup.sh` - Backup data volumes (planned)
- `restore.sh` - Restore from backup (planned)
- `health-check.sh` - Manual health checks (planned)

### development/
Development helper scripts:
- `reset-env.sh` - Reset environment (planned)
- `logs-tail.sh` - Tail service logs (planned)

## Usage

Execute scripts from project root:
```bash
./scripts/analysis/run-analysis.sh
```

Most scripts are also available via Makefile:
```bash
make health-all
make logs
```

## Adding New Scripts

1. Place in appropriate subdirectory
2. Make executable: `chmod +x scripts/category/script.sh`
3. Add Makefile target if commonly used
4. Document in this README

