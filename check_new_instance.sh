#!/usr/bin/env bash
# Check the new Vast.ai instance with high network speeds

set -euo pipefail

INSTANCE_ID=30109949
VASTAI_CMD="/opt/homebrew/bin/vastai"

echo "🔍 Checking New Vast.ai Instance (High Network Speed)"
echo "======================================================"
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
    
    echo "📝 Connection Details:"
    echo "   Host: $HOST"
    echo "   Port: $PORT"
    echo "   Command: ssh root@$HOST -p $PORT"
    echo ""
    
    # Extract network speeds from status
    NET_UP=$(echo "$STATUS" | awk '{for(i=1;i<=NF;i++) if($i=="Net") {print $(i+1); break}}' | head -1)
    NET_DOWN=$(echo "$STATUS" | awk '{for(i=1;i<=NF;i++) if($i=="down") {print $(i+1); break}}' | head -1)
    
    if [ -n "$NET_UP" ] && [ -n "$NET_DOWN" ]; then
        echo "🌐 Network Speeds:"
        echo "   Upload: $NET_UP Mbps (~$(echo "scale=1; $NET_UP/1000" | bc) Gbps)"
        echo "   Download: $NET_DOWN Mbps (~$(echo "scale=1; $NET_DOWN/1000" | bc) Gbps)"
        echo "   Total: $(echo "$NET_UP + $NET_DOWN" | bc) Mbps (~$(echo "scale=1; ($NET_UP + $NET_DOWN)/1000" | bc) Gbps)"
    fi
    echo ""
    
    # Check if instance is running
    if echo "$STATUS" | grep -q "running"; then
        echo "✅ Instance is running! You can connect now."
        echo ""
        echo "🚀 Quick connect:"
        echo "   ssh root@$HOST -p $PORT"
        echo ""
        echo "📋 Once connected, check for smctm:"
        echo "   cd /workspace"
        echo "   ls -la smctm/"
        echo "   env | grep PROJECT_REPO"
    elif echo "$STATUS" | grep -q "loading"; then
        echo "⏳ Instance is loading (pulling Docker image)..."
        echo "   With high network speeds, this should be faster than before!"
        echo "   Wait a few minutes and run this script again."
    else
        echo "⚠️  Instance status: $(echo "$STATUS" | grep -oP 'Status\s+\K\S+' || echo 'unknown')"
    fi
fi

echo ""
echo "💡 To check status again:"
echo "   $VASTAI_CMD show instance $INSTANCE_ID"
echo ""
echo "💡 To view logs:"
echo "   $VASTAI_CMD logs $INSTANCE_ID"
