#!/usr/bin/env bash
# Test SSH connection and check for smctm

INSTANCE_IP="${1:-142.170.89.112}"
INSTANCE_PORT="${2:-62050}"
SSH_KEY="${3:-$HOME/.ssh/vastai}"

echo "🔍 Testing SSH Connection"
echo "========================="
echo "Host: $INSTANCE_IP"
echo "Port: $INSTANCE_PORT"
echo ""

# Test basic connection
echo "Testing connection..."
if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes root@"$INSTANCE_IP" -p "$INSTANCE_PORT" 'echo "Connection test successful"' 2>&1 | grep -q "Connection test successful"; then
    echo "✅ SSH connection is working!"
    echo ""
    echo "📝 To connect and check for smctm:"
    echo "   ssh -i $SSH_KEY root@$INSTANCE_IP -p $INSTANCE_PORT"
    echo ""
    echo "   Once connected (ignore tmux errors), run:"
    echo "   touch ~/.no_auto_tmux"
    echo "   apt-get update && apt-get install -y tmux"
    echo "   ls -la /workspace/"
    echo "   ls -la /workspace/smctm/"
else
    echo "⚠️  Connection test failed or timed out"
    echo ""
    echo "Try connecting manually:"
    echo "   ssh -i $SSH_KEY root@$INSTANCE_IP -p $INSTANCE_PORT"
fi
