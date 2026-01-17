#!/usr/bin/env bash
# Quick script to clone smctm on current instance - copy commands to run on remote

set -euo pipefail

# Load .env to get GITHUB_PAT
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

echo "📋 Clone smctm on Remote Instance"
echo "==================================="
echo ""
echo "Your GITHUB_PAT is configured in .env"
echo ""
echo "📝 Copy and paste these commands on your remote instance:"
echo ""
echo "================================"
echo ""

if [ -n "${GITHUB_PAT:-}" ]; then
    echo "# Option 1: Clone with your GITHUB_PAT (recommended)"
    echo "export GITHUB_PAT=\"${GITHUB_PAT}\""
    echo "cd /workspace"
    echo "GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/echo git clone \"https://\${GITHUB_PAT}@github.com/almaghrabima/smctm.git\" smctm < /dev/null"
    echo "ls -la /workspace/smctm/ && cd /workspace/smctm && git status"
    echo ""
    echo "================================"
    echo ""
    echo "# Option 2: One-liner (copy entire line)"
    echo "export GITHUB_PAT=\"${GITHUB_PAT}\" && cd /workspace && GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/echo git clone \"https://\${GITHUB_PAT}@github.com/almaghrabima/smctm.git\" smctm < /dev/null && ls -la /workspace/smctm/ && cd /workspace/smctm && git status"
else
    echo "⚠️  GITHUB_PAT not found in .env"
    echo ""
    echo "Option 1: Clone without authentication (if repo is public)"
    echo "cd /workspace"
    echo "GIT_TERMINAL_PROMPT=0 git clone https://github.com/almaghrabima/smctm.git smctm"
    echo ""
    echo "Option 2: Set GITHUB_PAT manually"
    echo "export GITHUB_PAT=\"your_pat_here\""
    echo "cd /workspace"
    echo "GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/echo git clone \"https://\${GITHUB_PAT}@github.com/almaghrabima/smctm.git\" smctm < /dev/null"
fi

echo ""
echo "================================"
echo ""
echo "💡 After cloning, the onstart script will work on future instances"
echo "   created from templates with environment variables configured."
