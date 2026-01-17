#!/usr/bin/env bash
# Connect to vast.ai instance with port forward and check for smctm

HOST="69.63.236.187"
PORT="26002"
LOCAL_PORT="8080"
SSH_KEY="/Users/mohammedalmaghrabi/.ssh/vastai"

echo "🔗 Connecting to vast.ai instance"
echo "================================="
echo "Host: $HOST"
echo "Port: $PORT"
echo "SSH Key: $SSH_KEY"
echo "Port Forward: $LOCAL_PORT -> localhost:$LOCAL_PORT"
echo ""
echo "📋 Once connected, run these commands to check for smctm:"
echo ""
echo "   # Disable tmux auto-start for this session"
echo "   touch ~/.no_auto_tmux"
echo "   exit"
echo ""
echo "   # Then reconnect and run:"
echo "   ls -la /workspace/"
echo "   ls -la /workspace/smctm/ 2>/dev/null || echo 'smctm not found'"
echo "   cd /workspace/smctm && git status"
echo "   env | grep PROJECT_REPO"
echo ""
echo "🚀 Connecting now..."
echo "   (Press Ctrl+D or type 'exit' to disconnect)"
echo ""

ssh -i "$SSH_KEY" \
    -o StrictHostKeyChecking=no \
    -p "$PORT" \
    root@"$HOST" \
    -L "$LOCAL_PORT:localhost:$LOCAL_PORT"
