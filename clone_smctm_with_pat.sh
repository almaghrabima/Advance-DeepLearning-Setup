#!/usr/bin/env bash
# Clone smctm using GITHUB_PAT - Commands to run on remote instance

echo "📋 Clone smctm using GITHUB_PAT"
echo "================================"
echo ""
echo "Step 1: Get your GITHUB_PAT from your local .env file:"
echo "   cat .env | grep GITHUB_PAT"
echo ""
echo "Step 2: On the remote instance, run these commands:"
echo ""
echo "================================"
echo ""
echo "🚀 Option 1: Set GITHUB_PAT and clone (recommended)"
echo ""
cat << 'EOF'
# Replace YOUR_GITHUB_PAT_HERE with your actual PAT
export GITHUB_PAT="YOUR_GITHUB_PAT_HERE"
export GITHUB_REPO="https://github.com/almaghrabima/smctm.git"

cd /workspace
REPO_PATH="${GITHUB_REPO#https://github.com/}"
AUTH_REPO_URL="https://${GITHUB_PAT}@github.com/${REPO_PATH}"

echo "Cloning smctm with authentication..."
GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/echo git clone "$AUTH_REPO_URL" smctm < /dev/null

# Verify
if [ -d /workspace/smctm ]; then
    echo "✅ smctm cloned successfully!"
    ls -la /workspace/smctm/ | head -10
    cd /workspace/smctm && git status
else
    echo "❌ Clone failed"
fi
EOF
echo ""
echo "================================"
echo ""
echo "🚀 Option 2: One-liner (replace YOUR_PAT)"
echo ""
cat << 'EOF'
export GITHUB_PAT="YOUR_GITHUB_PAT_HERE" && cd /workspace && GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/echo git clone "https://${GITHUB_PAT}@github.com/almaghrabima/smctm.git" smctm < /dev/null && ls -la /workspace/smctm/ && cd /workspace/smctm && git status
EOF
echo ""
echo "================================"
echo ""
echo "📝 Example with actual PAT (DO NOT share your real PAT):"
echo ""
cat << 'EOF'
# Example format (your PAT starts with ghp_)
export GITHUB_PAT="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
cd /workspace
GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/echo git clone "https://${GITHUB_PAT}@github.com/almaghrabima/smctm.git" smctm < /dev/null
EOF
echo ""
