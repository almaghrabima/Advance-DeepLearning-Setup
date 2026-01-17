#!/usr/bin/env bash
# Commands to fix smctm clone issue

echo "🔧 Fix smctm Clone Issue"
echo "========================"
echo ""
echo "The problem: Environment variables are not set!"
echo ""
echo "Run these commands on the remote instance:"
echo ""
echo "1. Check container environment variables:"
echo "   cat /proc/1/environ | tr '\\0' '\\n' | grep -E 'PROJECT_REPO|GITHUB_REPO|GITHUB_PAT'"
echo ""
echo "2. Check /etc/environment:"
echo "   cat /etc/environment"
echo ""
echo "3. Check the onstart script:"
echo "   cat /workspace/onstart.sh"
echo ""
echo "4. Check entrypoint script:"
echo "   head -30 /usr/local/bin/entrypoint.sh"
echo ""
echo "================================"
echo ""
echo "🚀 Solution: Manually clone smctm"
echo ""
echo "Option A: Clone with GITHUB_PAT (if you have it):"
cat << 'EOF'
export GITHUB_REPO="https://github.com/almaghrabima/smctm.git"
export GITHUB_PAT="your_pat_here"  # Replace with your actual PAT
cd /workspace
REPO_PATH="${GITHUB_REPO#https://github.com/}"
AUTH_REPO_URL="https://${GITHUB_PAT}@github.com/${REPO_PATH}"
GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/echo git clone "$AUTH_REPO_URL" smctm < /dev/null
ls -la /workspace/smctm/ && cd /workspace/smctm && git status
EOF
echo ""
echo "Option B: Clone without authentication (if repo is public):"
cat << 'EOF'
cd /workspace
GIT_TERMINAL_PROMPT=0 git clone https://github.com/almaghrabima/smctm.git smctm
ls -la /workspace/smctm/ && cd /workspace/smctm && git status
EOF
echo ""
echo "Option C: Manually run onstart script with environment variables:"
cat << 'EOF'
export GITHUB_REPO="https://github.com/almaghrabima/smctm.git"
export PROJECT_REPO="https://github.com/almaghrabima/smctm.git"
export GITHUB_PAT="your_pat_here"  # Replace with your actual PAT
bash /workspace/onstart.sh
# OR
bash /usr/local/bin/onstart.sh  # if it exists
EOF
echo ""
