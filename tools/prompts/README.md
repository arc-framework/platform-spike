# Prompts

AI prompt templates for automated analysis and documentation generation.

## Available Prompts

### PROMPT-analysis-template.md

**Purpose:** Repository analysis framework  
**Used by:** `tools/analysis/run-analysis.sh`  
**Generates:** Comprehensive repository analysis reports

**Usage:**

```bash
./tools/analysis/run-analysis.sh
# Generates analysis using this prompt template
```

**Output:** `docs/reports/MMDD-ANALYSIS.md` and `MMDD-CONCERNS_AND_ACTION_PLAN.md`

---

### PROMPT-journal-template.md

**Purpose:** Daily journal entry template  
**Used by:** `tools/journal/generate-journal.sh`  
**Generates:** Daily project journals with technical and non-technical summaries

**Usage:**

```bash
./tools/journal/generate-journal.sh
# Generates journal using this prompt template
```

**Output:** `journal/YYYY/MM/DD-journal.md`

---

## Creating New Prompts

### Naming Convention

All prompt templates should follow: `PROMPT-<purpose>-template.md`

Examples:

- `PROMPT-analysis-template.md`
- `PROMPT-journal-template.md`
- `PROMPT-documentation-template.md`
- `PROMPT-review-template.md`

### Template Structure

Each prompt should include:

1. **Purpose** - What the prompt generates
2. **Scope** - What aspects it analyzes
3. **Output Format** - Structure of generated content
4. **Instructions** - Clear guidance for AI
5. **Examples** - Sample outputs (if applicable)

### Integration

Link prompts to the corresponding tool scripts:

```bash
TEMPLATE_FILE="$PROJECT_ROOT/prompts/PROMPT-<name>-template.md"
```

---

## Prompt Categories

### Analysis Prompts

- Repository health checks
- Code quality assessments
- Architecture reviews
- Security audits

### Documentation Prompts

- Daily journals
- Sprint summaries
- Technical documentation
- API documentation

### Review Prompts

- Code review templates
- PR descriptions
- Release notes
- Changelog generation

---

## Best Practices

### 1. Keep Prompts Focused

Each prompt should have a single, clear purpose.

### 2. Use Structured Format

Consistent markdown structure makes prompts reusable.

### 3. Include Context

Provide enough context for AI to understand the project.

### 4. Define Output Format

Specify exact format, sections, and structure expected.

### 5. Add Examples

Include sample outputs to guide generation.

### 6. Version Control

Track prompt changes to improve over time.

---

## Using Prompts with AI

### With Scripts (Automated)

```bash
# Analysis
./tools/analysis/run-analysis.sh

# Journal
./tools/journal/generate-journal.sh
```

Scripts automatically:

1. Load the prompt template
2. Add current project context
3. Generate enhanced prompt
4. Create output files

### Manual Use

```bash
# Copy prompt to clipboard
cat prompts/PROMPT-analysis-template.md | pbcopy

# Or view and use manually
cat prompts/PROMPT-analysis-template.md
```

Then paste into:

- GitHub Copilot
- ChatGPT
- Claude
- Any AI assistant

---

## Customization

### Modify Existing Prompts

```bash
# Edit prompt template
vim prompts/PROMPT-analysis-template.md

# Test changes
./tools/analysis/run-analysis.sh
```

### Create New Prompts

```bash
# Create new template
cat > prompts/PROMPT-custom-template.md << 'EOF'
# Custom Prompt Template
...
EOF

# Reference in script
TEMPLATE_FILE="$PROJECT_ROOT/prompts/PROMPT-custom-template.md"
```

---

## Maintenance

### Regular Reviews

- Review prompt effectiveness monthly
- Update based on output quality
- Refine instructions for clarity

### Version History

Track changes in git:

```bash
git log -- prompts/
```

### Feedback Loop

1. Use prompt
2. Review output
3. Note improvements needed
4. Update prompt
5. Test again

---

## Integration with Workflow

```
┌─────────────────┐
│  prompts/       │
│  Templates      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  tools/         │
│  Automation     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  reports/       │
│  tools/journal/ │
│  Generated      │
└─────────────────┘
```

---

## Tips

### For Better Results

- Keep prompts up-to-date with project evolution
- Add specific project context
- Include examples of desired output
- Test prompts regularly
- Iterate based on feedback

### Common Issues

- **Generic output**: Add more specific context to prompt
- **Missing sections**: Update template structure
- **Wrong format**: Clarify output format in prompt
- **Inconsistent**: Standardize prompt structure

---

## Quick Reference

| Prompt                        | Purpose       | Script                              | Output                   |
| ----------------------------- | ------------- | ----------------------------------- | ------------------------ |
| `PROMPT-analysis-template.md` | Repo analysis | `tools/analysis/run-analysis.sh`    | `reports/YYYY/MM/`       |
| `PROMPT-journal-template.md`  | Daily journal | `tools/journal/generate-journal.sh` | `tools/journal/entries/` |

---

## Future Prompts (Planned)

- `PROMPT-documentation-template.md` - Auto-generate docs
- `PROMPT-review-template.md` - Code review assistance
- `PROMPT-release-notes-template.md` - Generate release notes
- `PROMPT-architecture-template.md` - Architecture documentation

---

_Prompt templates for AI-assisted development_  
_Part of A.R.C. Platform Spike_
