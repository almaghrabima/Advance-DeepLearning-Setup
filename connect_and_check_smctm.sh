#!/usr/bin/env bash
# Connect to instance with port forward and check for smctm

HOST="69.63.236.187"
PORT="26002"
LOCAL_PORT="8080"

echo "🔗 Connecting to instance with port forward"
echo "============================================"
echo "Host: $HOST"
echo "Port: $PORT"
echo "Port Forward: $LOCAL_PORT -> localhost:$LOCAL_PORT"
echo ""
echo "📋 Once connected, run these commands to check for smctm:"
echo ""
echo "   # Check workspace contents"
echo "   ls -la /workspace/"
echo ""
echo "   # Check if smctm exists"
echo "   ls -la /workspace/smctm/ 2>/dev/null || echo 'smctm not found'"
echo ""
echo "   # If smctm exists, check git status"
echo "   cd /workspace/smctm && git status"
echo ""
echo "   # Check environment variables"
echo "   env | grep -E 'PROJECT_REPO|GITHUB_REPO|GIT_USER'"
echo ""
echo "🚀 Connecting now..."
echo ""

# Try different SSH keys
SSH_KEYS=(
    "$HOME/.ssh/id_ed25519"
    "$HOME/.ssh/id_rsa"
    "$HOME/.ssh/id_ecdsa"
)

SSH_KEY=""
for key in "${SSH_KEYS[@]}"; do
    if [ -f "$key" ]; then
        SSH_KEY="-i $key"
        echo "Using SSH key: $key"
        break
    fi
done

if [ -z "$SSH_KEY" ]; then
    echo "⚠️  No SSH key found. You'll need to specify one manually."
    echo ""
    echo "Run this command manually:"
    echo "  ssh -i ~/.ssh/your_key -p $PORT root@$HOST -L $LOCAL_PORT:localhost:$LOCAL_PORT"
    exit 1
fi

# Connect with port forward
ssh $SSH_KEY \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -p $PORT \
    root@$HOST \
    -L $LOCAL_PORT:localhost:$LOCAL_PORT
