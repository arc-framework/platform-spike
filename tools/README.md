# Development & Analysis Tools

This directory contains utilities for development, validation, and analysis.

## Structure

- **analysis/** - Repository analysis system
  - `prompt-template.md` - Analysis framework template
  - Runner script in `../../scripts/analysis/`
  
- **validation/** - Configuration and environment validation scripts
  - `validate-env.sh` - Validate environment variables

- **generators/** - Code and configuration generators
  - `env-generator.sh` - Generate environment files

## Usage

Tools are typically executed via Makefile targets or directly from scripts/ directory.

For analysis system: `./scripts/analysis/run-analysis.sh`

