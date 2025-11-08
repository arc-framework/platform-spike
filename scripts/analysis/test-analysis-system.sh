#!/bin/bash
# Quick test of the analysis system
# Run this to verify everything works

echo "🧪 Testing Repository Analysis System..."
echo ""

# Test 1: Check if template exists
if [ -f "tools/analysis/prompt-template.md" ]; then
    echo "✅ Template found"
else
    echo "❌ Template missing"
    exit 1
fi

# Test 2: Check if script exists and is executable
if [ -x "scripts/analysis/run-analysis.sh" ]; then
    echo "✅ Runner script executable"
else
    echo "❌ Runner script not executable"
    exit 1
fi

# Test 3: Check if report directory exists
if [ -d "docs/reports" ]; then
    echo "✅ Report directory exists"
else
    echo "❌ Report directory missing"
    exit 1
fi

# Test 4: Check documentation files
docs=(
    "docs/analysis/INDEX.md"
    "docs/analysis/QUICK-REF.md"
    "docs/analysis/SYSTEM-GUIDE.md"
    "docs/analysis/SETUP.md"
)

for doc in "${docs[@]}"; do
    if [ -f "$doc" ]; then
        echo "✅ $doc found"
    else
        echo "❌ $doc missing"
        exit 1
    fi
done

# Test 5: Run script help
echo ""
echo "🔍 Testing script execution..."
./scripts/analysis/run-analysis.sh --help > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Script runs successfully"
else
    echo "❌ Script execution failed"
    exit 1
fi

echo ""
echo "🎉 All tests passed! System is ready to use."
echo ""
echo "📚 Quick Reference:"
echo "   ./scripts/analysis/run-analysis.sh   → Run analysis"
echo "   cat docs/analysis/QUICK-REF.md       → View quick ref"
echo "   cat docs/analysis/INDEX.md           → Navigate docs"
echo ""
echo "✨ Ready to analyze repositories!"

