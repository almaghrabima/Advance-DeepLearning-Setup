#!/usr/bin/env bash
# Diagnose why onstart script didn't clone smctm

echo "🔍 Diagnosing onstart script issue"
echo "===================================="
echo ""
echo "Run these commands on the remote instance:"
echo ""
echo "1. Check if onstart script exists:"
echo "   ls -la /workspace/onstart.sh"
echo "   ls -la /usr/local/bin/onstart.sh"
echo ""
echo "2. Check onstart log:"
echo "   cat /var/log/onstart.log 2>&1 | tail -50"
echo ""
echo "3. Check environment variables (current session):"
echo "   env | grep -E 'PROJECT_REPO|GITHUB_REPO|GITHUB_PAT'"
echo ""
echo "4. Check if entrypoint exists:"
echo "   ls -la /usr/local/bin/entrypoint.sh"
echo ""
echo "5. Check container environment variables:"
echo "   cat /proc/1/environ | tr '\\0' '\\n' | grep -E 'PROJECT_REPO|GITHUB_REPO|GITHUB_PAT'"
echo ""
echo "6. Check /etc/environment:"
echo "   cat /etc/environment | grep -E 'PROJECT_REPO|GITHUB_REPO|GITHUB_PAT'"
echo ""
echo "7. Manually run onstart script to see what happens:"
echo "   bash /workspace/onstart.sh 2>&1 | tail -30"
echo "   # OR"
echo "   bash /usr/local/bin/onstart.sh 2>&1 | tail -30"
echo ""
echo "================================"
echo ""
echo "🚀 Quick diagnostic one-liner:"
echo ""
cat << 'EOF'
echo "=== Onstart Script Locations ===" && \
ls -la /workspace/onstart.sh /usr/local/bin/onstart.sh 2>&1 && \
echo "" && \
echo "=== Onstart Log (last 50 lines) ===" && \
cat /var/log/onstart.log 2>&1 | tail -50 && \
echo "" && \
echo "=== Current Environment Variables ===" && \
env | grep -E "PROJECT_REPO|GITHUB_REPO|GITHUB_PAT" && \
echo "" && \
echo "=== Container Environment Variables ===" && \
cat /proc/1/environ 2>&1 | tr '\0' '\n' | grep -E "PROJECT_REPO|GITHUB_REPO|GITHUB_PAT" && \
echo "" && \
echo "=== /etc/environment ===" && \
cat /etc/environment 2>&1 | grep -E "PROJECT_REPO|GITHUB_REPO|GITHUB_PAT" || echo "No matches"
EOF
echo ""
