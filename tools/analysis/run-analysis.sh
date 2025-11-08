#!/bin/bash
# Repository Analysis Runner Script
# Version: 1.0
# Usage: ./scripts/run-analysis.sh [MMDD] [--compare]

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPORT_DIR="$PROJECT_ROOT/reports"
TEMPLATE_FILE="$PROJECT_ROOT/tools/prompts/template-analysis.md"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default date (current date in MMDD format)
DEFAULT_DATE=$(date +%d%m)
ANALYSIS_DATE="${1:-$DEFAULT_DATE}"
COMPARE_MODE=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --compare)
            COMPARE_MODE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [MMDD] [--compare]"
            echo ""
            echo "Arguments:"
            echo "  MMDD        Date in MMDD format (default: today)"
            echo "  --compare   Compare with previous analysis"
            echo ""
            echo "Examples:"
            echo "  $0                    # Run analysis for today"
            echo "  $0 1115               # Run analysis for Nov 15"
            echo "  $0 --compare          # Run and compare with previous"
            exit 0
            ;;
    esac
done

# Validate date format
if ! [[ "$ANALYSIS_DATE" =~ ^[0-9]{4}$ ]]; then
    echo -e "${RED}✗ Error: Date must be in MMDD format (e.g., 1108)${NC}"
    exit 1
fi

# Check if template exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo -e "${RED}✗ Error: Analysis template not found at $TEMPLATE_FILE${NC}"
    exit 1
fi

# Create report directory if it doesn't exist
mkdir -p "$REPORT_DIR"

# Report file names
ANALYSIS_REPORT="$REPORT_DIR/${ANALYSIS_DATE}-ANALYSIS.md"
CONCERNS_REPORT="$REPORT_DIR/${ANALYSIS_DATE}-CONCERNS_AND_ACTION_PLAN.md"

# Check if reports already exist
if [ -f "$ANALYSIS_REPORT" ] || [ -f "$CONCERNS_REPORT" ]; then
    echo -e "${YELLOW}⚠ Warning: Reports for $ANALYSIS_DATE already exist${NC}"
    read -p "Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Analysis cancelled${NC}"
        exit 0
    fi
fi

# Find previous reports for comparison
PREVIOUS_ANALYSIS=""
PREVIOUS_CONCERNS=""
if [ "$COMPARE_MODE" = true ]; then
    PREVIOUS_ANALYSIS=$(ls -t "$REPORT_DIR"/*-ANALYSIS.md 2>/dev/null | grep -v "$ANALYSIS_DATE" | head -n 1 || echo "")
    PREVIOUS_CONCERNS=$(ls -t "$REPORT_DIR"/*-CONCERNS_AND_ACTION_PLAN.md 2>/dev/null | grep -v "$ANALYSIS_DATE" | head -n 1 || echo "")

    if [ -n "$PREVIOUS_ANALYSIS" ]; then
        echo -e "${GREEN}✓ Found previous analysis: $(basename "$PREVIOUS_ANALYSIS")${NC}"
    else
        echo -e "${YELLOW}⚠ No previous analysis found for comparison${NC}"
    fi
fi

# Display banner
echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║         Repository Analysis Runner v1.0                    ║"
echo "║         Automated Infrastructure Assessment                ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Display configuration
echo -e "${BLUE}Configuration:${NC}"
echo "  Project Root:    $PROJECT_ROOT"
echo "  Report Date:     $ANALYSIS_DATE"
echo "  Output Dir:      $REPORT_DIR"
echo "  Compare Mode:    $COMPARE_MODE"
if [ -n "$PREVIOUS_ANALYSIS" ]; then
    echo "  Compare With:    $(basename "$PREVIOUS_ANALYSIS")"
fi
echo ""

# Read template
echo -e "${BLUE}📖 Reading analysis template...${NC}"
TEMPLATE_CONTENT=$(cat "$TEMPLATE_FILE")

# Build the analysis prompt
ANALYSIS_PROMPT="I need you to analyze this repository using the following comprehensive analysis framework.

Date: $(date +"%B %d, %Y")
Report Date Code: $ANALYSIS_DATE

Repository Analysis Framework:
$TEMPLATE_CONTENT

---

ANALYSIS INSTRUCTIONS:

1. Conduct a thorough analysis of this repository following all dimensions in the template
2. Generate TWO comprehensive reports:
   - $ANALYSIS_REPORT
   - $CONCERNS_REPORT

3. Use the exact file naming convention specified above

4. Follow the report structure requirements exactly as defined in the template
"

if [ "$COMPARE_MODE" = true ] && [ -n "$PREVIOUS_ANALYSIS" ]; then
    ANALYSIS_PROMPT="$ANALYSIS_PROMPT
5. COMPARISON REQUIRED: Compare findings with previous analysis:
   Previous Analysis: $PREVIOUS_ANALYSIS
   Previous Concerns: $PREVIOUS_CONCERNS

   In the analysis report, include a section showing:
   - ✅ Issues resolved since last analysis
   - 🆕 New issues identified
   - 📉 Issues that regressed
   - ⏸️ Issues unchanged
   - 📈 Improvements made
"
fi

ANALYSIS_PROMPT="$ANALYSIS_PROMPT

6. Save both reports in the report/ directory with proper naming

7. After generating reports, provide a brief summary of:
   - Overall grade
   - Critical issues count
   - High priority issues count
   - Key recommendations

Now proceed with the analysis.
"

# Display prompt preview
echo -e "${BLUE}📝 Analysis prompt prepared${NC}"
echo -e "${YELLOW}Prompt length: ${#ANALYSIS_PROMPT} characters${NC}"
echo ""

# Save prompt to temporary file for reference
PROMPT_FILE="/tmp/repo-analysis-prompt-$ANALYSIS_DATE.txt"
echo "$ANALYSIS_PROMPT" > "$PROMPT_FILE"

echo -e "${GREEN}✓ Analysis prompt saved to: $PROMPT_FILE${NC}"
echo ""
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}NEXT STEPS:${NC}"
echo ""
echo -e "1. Copy the analysis prompt from: ${BLUE}$PROMPT_FILE${NC}"
echo ""
echo -e "2. Provide it to your AI assistant (GitHub Copilot, ChatGPT, etc.)"
echo ""
echo -e "3. The AI will analyze the repository and generate:"
echo -e "   ${GREEN}→${NC} $ANALYSIS_REPORT"
echo -e "   ${GREEN}→${NC} $CONCERNS_REPORT"
echo ""
echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
echo ""

# Option to display the prompt
read -p "Display the full prompt now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    cat "$PROMPT_FILE"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
fi

# Quick command to copy to clipboard (if available)
if command -v pbcopy &> /dev/null; then
    echo "$ANALYSIS_PROMPT" | pbcopy
    echo -e "${GREEN}✓ Prompt copied to clipboard (macOS)${NC}"
elif command -v xclip &> /dev/null; then
    echo "$ANALYSIS_PROMPT" | xclip -selection clipboard
    echo -e "${GREEN}✓ Prompt copied to clipboard (Linux)${NC}"
elif command -v clip.exe &> /dev/null; then
    echo "$ANALYSIS_PROMPT" | clip.exe
    echo -e "${GREEN}✓ Prompt copied to clipboard (Windows/WSL)${NC}"
fi

echo ""
echo -e "${GREEN}✓ Analysis runner completed${NC}"
echo -e "${BLUE}Waiting for AI to generate reports...${NC}"

