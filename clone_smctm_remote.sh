#!/usr/bin/env bash
# Script to diagnose and clone smctm on remote instance

echo "📋 Commands to diagnose and clone smctm"
echo "========================================"
echo ""
echo "1. Check environment variables:"
echo "   env | grep -E 'PROJECT_REPO|GITHUB_REPO|GITHUB_PAT'"
echo ""
echo "2. Check onstart log:"
echo "   cat /var/log/onstart.log 2>/dev/null | tail -30 || echo 'No log found'"
echo ""
echo "3. Check if entrypoint exists:"
echo "   ls -la /usr/local/bin/entrypoint.sh"
echo ""
echo "4. Check workspace onstart script:"
echo "   cat /workspace/onstart.sh"
echo ""
echo "================================"
echo ""
echo "🚀 Manual clone command (if needed):"
echo ""
cat << 'EOF'
# Set variables if not set
export GITHUB_REPO="${GITHUB_REPO:-https://github.com/almaghrabima/smctm.git}"
export GITHUB_PAT="${GITHUB_PAT:-}"

# Clone smctm
cd /workspace
if [ -n "$GITHUB_PAT" ]; then
    REPO_PATH="${GITHUB_REPO#https://github.com/}"
    AUTH_REPO_URL="https://${GITHUB_PAT}@github.com/${REPO_PATH}"
    GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/echo git clone "$AUTH_REPO_URL" smctm < /dev/null
else
    GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/echo git clone "$GITHUB_REPO" smctm < /dev/null
fi

# Verify
ls -la /workspace/smctm/ && cd /workspace/smctm && git status
EOF
echo ""
echo "================================"
echo ""
echo "📝 One-liner to check and clone:"
echo ""
cat << 'EOF'
env | grep -E "PROJECT_REPO|GITHUB_REPO|GITHUB_PAT" && echo "" && if [ -d /workspace/smctm ]; then echo "✅ smctm already exists"; else echo "📥 Cloning smctm..." && cd /workspace && GITHUB_REPO="${GITHUB_REPO:-https://github.com/almaghrabima/smctm.git}" && if [ -n "${GITHUB_PAT:-}" ]; then REPO_PATH="${GITHUB_REPO#https://github.com/}" && AUTH_REPO_URL="https://${GITHUB_PAT}@github.com/${REPO_PATH}" && GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/echo git clone "$AUTH_REPO_URL" smctm < /dev/null; else GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/echo git clone "$GITHUB_REPO" smctm < /dev/null; fi && ls -la /workspace/smctm/ && cd /workspace/smctm && git status; fi
EOF
echo ""
