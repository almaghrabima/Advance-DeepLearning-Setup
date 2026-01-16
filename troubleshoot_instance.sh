#!/usr/bin/env bash
# Troubleshoot Vast.ai instance that's stuck loading

set -euo pipefail

INSTANCE_ID=30109581
VASTAI_CMD="/opt/homebrew/bin/vastai"

echo "🔧 Troubleshooting Vast.ai Instance"
echo "====================================="
echo "Instance ID: $INSTANCE_ID"
echo ""

echo "📊 Current Status:"
$VASTAI_CMD show instance $INSTANCE_ID 2>&1
echo ""

echo "💡 Options:"
echo ""
echo "Option 1: Wait longer (17.9GB image takes time to pull)"
echo "   Large Docker images can take 5-10 minutes to pull, especially on slower connections."
echo "   The instance might still be downloading in the background."
echo ""

echo "Option 2: Destroy and recreate with a smaller/faster instance"
echo "   /opt/homebrew/bin/vastai destroy instance $INSTANCE_ID"
echo "   # Then create a new one with better network/disk"
echo ""

echo "Option 3: Try to SSH in and check manually"
SSH_URL=$($VASTAI_CMD ssh-url $INSTANCE_ID 2>&1)
if echo "$SSH_URL" | grep -q "ssh://"; then
    HOST_PORT=$(echo "$SSH_URL" | sed 's|ssh://root@||' | sed 's|ssh://||')
    HOST=$(echo "$HOST_PORT" | cut -d: -f1)
    PORT=$(echo "$HOST_PORT" | cut -d: -f2)
    echo "   ssh root@$HOST -p $PORT"
    echo "   # Then check: docker ps, docker images, docker pull status"
fi
echo ""

echo "Option 4: Check if image pull completed but container failed to start"
echo "   Try SSH and run: docker ps -a"
echo "   Check logs: docker logs <container_id>"
echo ""

echo "Option 5: Recreate instance with the same image (might have better network)"
echo "   /opt/homebrew/bin/vastai destroy instance $INSTANCE_ID"
echo "   /opt/homebrew/bin/vastai create instance <offer_id> --image almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai --env 'GIT_USER_EMAIL=...' --ssh"
echo ""

echo "⏳ Recommended: Wait 5 more minutes, then check status again:"
echo "   $VASTAI_CMD show instance $INSTANCE_ID"
echo ""
