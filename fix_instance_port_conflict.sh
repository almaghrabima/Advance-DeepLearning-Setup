#!/usr/bin/env bash
# Fix port conflict for Vast.ai instance by stopping and restarting
# Usage: ./fix_instance_port_conflict.sh [instance_id]

set -euo pipefail

INSTANCE_ID="${1:-30139641}"
VASTAI_CMD="${VASTAI_CMD:-/opt/homebrew/bin/vastai}"

echo "🔧 Fixing Port Conflict for Vast.ai Instance"
echo "============================================"
echo "Instance ID: $INSTANCE_ID"
echo ""

# Check instance status
echo "1️⃣ Checking instance status..."
STATUS=$($VASTAI_CMD show instance $INSTANCE_ID 2>&1 | grep -i "status" || echo "Status: unknown")
echo "$STATUS"
echo ""

# Stop the instance
echo "2️⃣ Stopping instance to release ports..."
if $VASTAI_CMD stop instance $INSTANCE_ID 2>&1; then
    echo "   ✅ Instance stop command sent"
    echo "   ⏳ Waiting 10 seconds for ports to be released..."
    sleep 10
else
    echo "   ⚠️  Failed to stop instance (may already be stopped)"
fi
echo ""

# Check status again
echo "3️⃣ Checking instance status after stop..."
NEW_STATUS=$($VASTAI_CMD show instance $INSTANCE_ID 2>&1 | grep -i "status" || echo "Status: unknown")
echo "$NEW_STATUS"
echo ""

echo "4️⃣ Next Steps"
echo "============"
echo ""
echo "Option A: Restart the instance"
echo "   $VASTAI_CMD start instance $INSTANCE_ID"
echo ""
echo "Option B: Destroy and recreate (if you need a fresh start)"
echo "   $VASTAI_CMD destroy instance $INSTANCE_ID"
echo "   # Then create a new instance from your template"
echo ""
echo "Option C: Wait a bit longer (if container is still shutting down)"
echo "   # Ports may take 30-60 seconds to fully release"
echo "   # Then try your operation again"
echo ""

# If instance is stopped, offer to start it
if echo "$NEW_STATUS" | grep -qi "stopped"; then
    echo "💡 Instance is now stopped. You can:"
    echo "   1. Start it: $VASTAI_CMD start instance $INSTANCE_ID"
    echo "   2. Or destroy it and create a new one"
fi
