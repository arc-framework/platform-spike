# Project Journal System

Automated daily journal generation that tracks project evolution, technical implementations, and architectural decisions.

## Overview

This system automatically generates daily journal entries by:
1. Analyzing git commits and changes
2. Summarizing technical implementations
3. Explaining concepts in non-technical terms
4. Tracking architectural decisions
5. Comparing with previous entries to show evolution

## Structure

```
journal/
├── README.md (this file)
├── 2025/
│   ├── 11/
│   │   ├── 08-journal.md
│   │   ├── 09-journal.md
│   │   └── ...
└── archives/

Note: Journal template is in prompts/PROMPT-journal-template.md
```

## Usage

### Generate Today's Journal
```bash
./scripts/journal/generate-journal.sh
```

### Generate for Specific Date
```bash
./scripts/journal/generate-journal.sh 2025-11-08
```

### View Latest Journal
```bash
cat journal/$(date +%Y)/$(date +%m)/$(date +%d)-journal.md
```

### Compare with Previous Day
```bash
# Automatically included in journal generation
./scripts/journal/generate-journal.sh --compare
```

## What Gets Captured

### Technical Summary
- Git commits since last journal
- Files changed
- Lines added/removed
- New features implemented
- Bug fixes applied

### Architecture & Design
- New services added
- Configuration changes
- Infrastructure updates
- Integration patterns

### Non-Technical Explanation
- What the changes mean in simple terms
- Business value delivered
- User-facing improvements
- System capabilities enhanced

### Ideas & Decisions
- Architectural decisions made
- Design patterns applied
- Trade-offs considered
- Future considerations

## Journal Entry Format

Each entry contains:
- **Date & Summary**: Quick overview of the day
- **Changes Overview**: Git statistics
- **Technical Implementation**: What was built
- **For Non-Technical Stakeholders**: Plain English explanation
- **Architectural Decisions**: Why choices were made
- **Comparison with Previous Day**: How things evolved
- **Next Steps**: Planned improvements

## Configuration

Edit `scripts/operations/generate-journal.sh` to customize:
- Output format
- Analysis depth
- Comparison range
- AI prompts

## Examples

See `journal/2025/11/08-journal.md` for a complete example.

## Integration

The journal system integrates with:
- Git history for change tracking
- Project structure analysis
- Documentation updates
- Analysis reports in `docs/reports/`

## Automation

### Daily Generation (Optional)
Add to crontab or CI/CD:
```bash
# Generate journal at end of workday (6 PM)
0 18 * * * cd /path/to/project && ./scripts/journal/generate-journal.sh
```

### Git Hook (Optional)
Add to `.git/hooks/post-commit`:
```bash
#!/bin/bash
# Update journal after each commit
./scripts/journal/generate-journal.sh --update
```

## Benefits

- **Accountability**: Clear record of daily progress
- **Onboarding**: New team members understand evolution
- **Documentation**: Automatic project history
- **Communication**: Explain technical work to stakeholders
- **Learning**: Track patterns and decisions over time

## Tips

1. **Run daily** for best continuity
2. **Review previous entries** to spot patterns
3. **Share with stakeholders** for transparency
4. **Archive monthly** to keep organized
5. **Use for retrospectives** to review progress

