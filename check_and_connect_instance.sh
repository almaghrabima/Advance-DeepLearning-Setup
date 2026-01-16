#!/usr/bin/env bash
# Check instance status and provide connection instructions

set -euo pipefail

INSTANCE_ID=30109581
VASTAI_CMD="/opt/homebrew/bin/vastai"

echo "🔍 Checking Vast.ai Instance Status"
echo "===================================="
echo "Instance ID: $INSTANCE_ID"
echo ""

# Check instance status
STATUS=$($VASTAI_CMD show instance $INSTANCE_ID 2>&1)
echo "$STATUS"
echo ""

# Get SSH URL
SSH_URL=$($VASTAI_CMD ssh-url $INSTANCE_ID 2>&1)
echo "🔐 SSH Connection:"
echo "   $SSH_URL"
echo ""

# Extract host and port
if echo "$SSH_URL" | grep -q "ssh://"; then
    HOST_PORT=$(echo "$SSH_URL" | sed 's|ssh://root@||' | sed 's|ssh://||')
    HOST=$(echo "$HOST_PORT" | cut -d: -f1)
    PORT=$(echo "$HOST_PORT" | cut -d: -f2)
    
    echo "📝 To connect:"
    echo "   ssh root@$HOST -p $PORT"
    echo ""
    echo "📋 Once connected, check for smctm:"
    echo "   cd /workspace"
    echo "   ls -la smctm/"
    echo "   env | grep PROJECT_REPO"
    echo "   env | grep GIT_USER"
    echo ""
    
    # Check if instance is running
    if echo "$STATUS" | grep -q "running"; then
        echo "✅ Instance is running! You can connect now."
        echo ""
        echo "🚀 Quick connect command:"
        echo "   ssh root@$HOST -p $PORT"
    elif echo "$STATUS" | grep -q "loading"; then
        echo "⏳ Instance is still loading. Wait a bit more and run this script again."
    else
        echo "⚠️  Instance status: $(echo "$STATUS" | grep -oP 'Status\s+\K\S+' || echo 'unknown')"
    fi
fi

echo ""
echo "💡 To check status again:"
echo "   $VASTAI_CMD show instance $INSTANCE_ID"
echo ""
echo "💡 To view all instances:"
echo "   $VASTAI_CMD show instances"
