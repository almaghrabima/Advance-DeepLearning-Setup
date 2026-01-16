#!/usr/bin/env bash
# Connect to Vast.ai instance with SSH key and port forwarding

set -euo pipefail

INSTANCE_ID=30109949
VASTAI_CMD="/opt/homebrew/bin/vastai"
SSH_KEY="${VAST_SSH_KEY:-$HOME/.ssh/vastai}"

echo "🔐 Vast.ai SSH Connection Helper"
echo "=================================="
echo ""

# Get instance details
echo "📊 Getting instance details..."
INSTANCE_INFO=$($VASTAI_CMD show instance $INSTANCE_ID 2>&1)
echo "$INSTANCE_INFO" | head -3
echo ""

# Try to extract SSH details
SSH_HOST=$(echo "$INSTANCE_INFO" | awk '/SSH Addr/ {for(i=1;i<=NF;i++) if($i=="Addr") print $(i+1)}' | head -1)
SSH_PORT=$(echo "$INSTANCE_INFO" | awk '/SSH Port/ {for(i=1;i<=NF;i++) if($i=="Port") print $(i+1)}' | head -1)

# Also try ssh-url command
SSH_URL=$($VASTAI_CMD ssh-url $INSTANCE_ID 2>&1)

if echo "$SSH_URL" | grep -q "ssh://"; then
    HOST_PORT=$(echo "$SSH_URL" | sed 's|ssh://root@||' | sed 's|ssh://||')
    HOST=$(echo "$HOST_PORT" | cut -d: -f1)
    PORT=$(echo "$HOST_PORT" | cut -d: -f2)
    
    echo "🔗 SSH Connection Details:"
    echo "   Host: $HOST"
    echo "   Port: $PORT"
    echo ""
    
    # Check if SSH key exists
    if [ -f "$SSH_KEY" ]; then
        echo "✅ SSH key found: $SSH_KEY"
        SSH_KEY_OPT="-i $SSH_KEY"
    elif [ -f "$SSH_KEY.pub" ]; then
        echo "✅ SSH public key found: $SSH_KEY.pub"
        SSH_KEY_OPT="-i $SSH_KEY"
    else
        echo "⚠️  SSH key not found at: $SSH_KEY"
        echo "   Using default SSH key"
        SSH_KEY_OPT=""
    fi
    echo ""
    
    echo "🚀 Connection Commands:"
    echo ""
    echo "Basic SSH:"
    echo "   ssh $SSH_KEY_OPT -p $PORT root@$HOST"
    echo ""
    echo "With port forwarding (Jupyter on 8080):"
    echo "   ssh $SSH_KEY_OPT -p $PORT -L 8080:localhost:8080 root@$HOST"
    echo ""
    echo "With port forwarding (Jupyter 8888 and code-server 13337):"
    echo "   ssh $SSH_KEY_OPT -p $PORT -L 8888:localhost:8888 -L 13337:localhost:13337 root@$HOST"
    echo ""
    
    # If user provided direct IP and port
    if [ -n "${1:-}" ] && [ -n "${2:-}" ]; then
        DIRECT_IP="$1"
        DIRECT_PORT="$2"
        echo "📝 Using provided connection details:"
        echo "   ssh $SSH_KEY_OPT -p $DIRECT_PORT -L 8080:localhost:8080 root@$DIRECT_IP"
        echo ""
        echo "🔗 Connecting now..."
        ssh $SSH_KEY_OPT -p "$DIRECT_PORT" -L 8080:localhost:8080 root@$DIRECT_IP
    else
        echo "💡 To connect with your provided IP/port:"
        echo "   ./connect_vastai.sh <IP> <PORT>"
        echo ""
        echo "   Example:"
        echo "   ./connect_vastai.sh 9.141.104.199 46669"
    fi
else
    echo "❌ Could not get SSH connection details"
    echo "   Check instance status: $VASTAI_CMD show instance $INSTANCE_ID"
fi
