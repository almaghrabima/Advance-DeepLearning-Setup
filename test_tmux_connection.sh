#!/usr/bin/env bash
# Test tmux connection to Vast.ai instance

INSTANCE_IP="${1:-136.59.129.136}"
INSTANCE_PORT="${2:-34194}"
SSH_KEY="${3:-$HOME/.ssh/vastai}"

echo "🔍 Testing tmux on Vast.ai Instance"
echo "===================================="
echo "Host: $INSTANCE_IP"
echo "Port: $INSTANCE_PORT"
echo ""
echo "📝 Connecting interactively..."
echo ""
echo "When you connect, you should:"
echo "  1. See the Vast.ai welcome banner"
echo "  2. Automatically enter a tmux session"
echo "  3. See 'Welcome to your vast.ai container! This session is running in \`tmux\`.'"
echo ""
echo "To test tmux commands:"
echo "  - Press Ctrl+b then 'd' to detach"
echo "  - Run 'tmux attach -t ssh_tmux' to reattach"
echo "  - Run 'tmux list-sessions' to see all sessions"
echo ""
echo "Connecting now..."
echo ""

# Connect with port forwarding
ssh -i "$SSH_KEY" \
    -o StrictHostKeyChecking=no \
    root@"$INSTANCE_IP" \
    -p "$INSTANCE_PORT" \
    -L 8080:localhost:8080
