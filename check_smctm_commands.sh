#!/usr/bin/env bash
# Commands to check for smctm once connected via SSH

echo "📋 Commands to check for smctm:"
echo "================================"
echo ""
echo "1. Check workspace contents:"
echo "   ls -la /workspace/"
echo ""
echo "2. Check if smctm directory exists:"
echo "   ls -la /workspace/smctm/ 2>/dev/null || echo 'smctm not found'"
echo ""
echo "3. If smctm exists, check its contents:"
echo "   cd /workspace/smctm && ls -la"
echo ""
echo "4. Check git status:"
echo "   cd /workspace/smctm && git status"
echo ""
echo "5. Check git remote:"
echo "   cd /workspace/smctm && git remote -v"
echo ""
echo "6. Check environment variables:"
echo "   env | grep -E 'PROJECT_REPO|GITHUB_REPO|GIT_USER|GITHUB_PAT'"
echo ""
echo "7. Check if repository was cloned:"
echo "   test -d /workspace/smctm/.git && echo '✅ Git repository found' || echo '❌ Not a git repository'"
echo ""
echo "8. Check for onstart logs:"
echo "   cat /var/log/onstart.log 2>/dev/null | tail -20 || echo 'No onstart log found'"
echo ""
echo "================================"
echo ""
echo "🚀 Quick check (run this after connecting):"
echo ""
cat << 'EOF'
# One-liner to check everything
echo "=== Workspace Contents ===" && \
ls -la /workspace/ && \
echo "" && \
echo "=== Checking smctm ===" && \
if [ -d /workspace/smctm ]; then \
  echo "✅ smctm directory found!" && \
  ls -la /workspace/smctm/ | head -10 && \
  echo "" && \
  cd /workspace/smctm && \
  echo "=== Git Status ===" && \
  git status 2>&1 | head -5 && \
  echo "" && \
  echo "=== Git Remote ===" && \
  git remote -v; \
else \
  echo "❌ smctm directory not found in /workspace/"; \
fi && \
echo "" && \
echo "=== Environment Variables ===" && \
env | grep -E 'PROJECT_REPO|GITHUB_REPO|GIT_USER' | head -5
EOF
