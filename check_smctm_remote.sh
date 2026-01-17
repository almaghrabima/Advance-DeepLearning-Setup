#!/usr/bin/env bash
# Connect to remote instance and check for smctm project

set -euo pipefail

HOST="${1:-69.63.236.187}"
PORT="${2:-26002}"
LOCAL_PORT="${3:-8080}"

echo "🔍 Checking for smctm on remote instance"
echo "========================================="
echo "Host: $HOST"
echo "Port: $PORT"
echo "Local port forward: $LOCAL_PORT -> localhost:$LOCAL_PORT"
echo ""

# Check if SSH key exists
SSH_KEY=""
if [ -f ~/.ssh/id_rsa ]; then
    SSH_KEY="-i ~/.ssh/id_rsa"
elif [ -f ~/.ssh/id_ed25519 ]; then
    SSH_KEY="-i ~/.ssh/id_ed25519"
elif [ -f ~/.ssh/id_ecdsa ]; then
    SSH_KEY="-i ~/.ssh/id_ecdsa"
fi

if [ -n "$SSH_KEY" ]; then
    echo "✅ Found SSH key: $SSH_KEY"
else
    echo "⚠️  No default SSH key found. You may need to specify one with -i"
fi

echo ""
echo "📋 Commands to run:"
echo ""

# Create a command that checks for smctm
CHECK_CMD="echo '=== Checking /workspace ===' && ls -la /workspace/ 2>&1 | head -20 && echo '' && echo '=== Checking for smctm directory ===' && if [ -d /workspace/smctm ]; then echo '✅ smctm directory found!' && ls -la /workspace/smctm/ | head -10 && echo '' && echo '=== Checking git status ===' && cd /workspace/smctm && git status 2>&1 | head -5; else echo '❌ smctm directory not found in /workspace/'; fi && echo '' && echo '=== Checking environment variables ===' && env | grep -E 'PROJECT_REPO|GITHUB_REPO|GIT_USER' | head -5"

echo "Option 1: Run check command directly (without port forward):"
echo "  ssh $SSH_KEY -o StrictHostKeyChecking=no -p $PORT root@$HOST \"$CHECK_CMD\""
echo ""

echo "Option 2: Interactive SSH with port forward:"
echo "  ssh $SSH_KEY -o StrictHostKeyChecking=no -p $PORT root@$HOST -L $LOCAL_PORT:localhost:$LOCAL_PORT"
echo "  Then run: ls -la /workspace/ && ls -la /workspace/smctm/"
echo ""

echo "Option 3: Run this script to execute the check:"
echo "  ./check_smctm_remote.sh $HOST $PORT"
echo ""

# Try to run the check if SSH key is available
if [ -n "$SSH_KEY" ]; then
    echo "🚀 Attempting to connect and check..."
    echo ""
    
    ssh $SSH_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p $PORT root@$HOST "$CHECK_CMD" 2>&1 || {
        echo ""
        echo "❌ Connection failed. Possible reasons:"
        echo "   1. SSH key not authorized on the server"
        echo "   2. Server is not accessible"
        echo "   3. Wrong port or host"
        echo ""
        echo "💡 Try manually:"
        echo "   ssh $SSH_KEY -p $PORT root@$HOST"
    }
else
    echo "⚠️  No SSH key found. Please run manually:"
    echo "   ssh -i ~/.ssh/your_key -p $PORT root@$HOST"
fi
