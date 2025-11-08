# Development & Analysis Tools

This directory contains utilities for development, validation, and analysis.

## Structure

- **analysis/** - Repository analysis system utilities
  - Analysis scripts located in `../../scripts/analysis/`
  - Prompt templates in `../../prompts/`
  
- **validation/** - Configuration and environment validation scripts
  - `validate-env.sh` - Validate environment variables

- **generators/** - Code and configuration generators
  - `env-generator.sh` - Generate environment files

## Usage

Tools are typically executed via Makefile targets or directly from scripts/ directory.

For analysis system: `./scripts/analysis/run-analysis.sh`

**Note:** Prompt templates have been moved to `prompts/` directory for better organization.

