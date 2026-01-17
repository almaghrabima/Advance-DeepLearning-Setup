#!/usr/bin/env bash
# Fix Docker port conflict for Vast.ai instances
# This script helps diagnose and fix "address already in use" errors

set -euo pipefail

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

VASTAI_CMD="/opt/homebrew/bin/vastai"
INSTANCE_ID="${1:-}"

if [ -z "$INSTANCE_ID" ]; then
    echo "❌ Error: Instance ID required"
    echo ""
    echo "Usage: $0 <instance_id>"
    echo "Example: $0 30136512"
    echo ""
    echo "Or to find your instances:"
    echo "   $VASTAI_CMD show instances"
    exit 1
fi

echo "🔧 Fixing Port Conflict for Instance $INSTANCE_ID"
echo "=================================================="
echo ""

# Check if API token is available
if [ -z "${VAST_API_TOKEN:-}" ]; then
    echo "⚠️  Warning: VAST_API_TOKEN not set. Some commands may fail."
    echo "   Set it in your .env file or export it."
    echo ""
fi

echo "📊 Step 1: Checking instance status..."
INSTANCE_INFO=$($VASTAI_CMD show instance $INSTANCE_ID 2>&1 || echo "ERROR")
echo "$INSTANCE_INFO"
echo ""

# Get SSH connection details
echo "📊 Step 2: Getting SSH connection details..."
SSH_URL=$($VASTAI_CMD ssh-url $INSTANCE_ID 2>&1 || echo "")
if [ -z "$SSH_URL" ] || echo "$SSH_URL" | grep -q "ERROR\|error\|not found"; then
    echo "❌ Could not get SSH URL. Instance may not exist or be accessible."
    echo ""
    echo "💡 Solutions:"
    echo "   1. Destroy and recreate the instance:"
    echo "      $VASTAI_CMD destroy instance $INSTANCE_ID"
    echo "      # Then create a new instance"
    echo ""
    echo "   2. Check if instance exists:"
    echo "      $VASTAI_CMD show instances"
    exit 1
fi

echo "✅ SSH URL: $SSH_URL"
echo ""

# Parse SSH details
if echo "$SSH_URL" | grep -q "ssh://"; then
    HOST_PORT=$(echo "$SSH_URL" | sed 's|ssh://root@||' | sed 's|ssh://||' | sed 's|/||')
    HOST=$(echo "$HOST_PORT" | cut -d: -f1)
    PORT=$(echo "$HOST_PORT" | cut -d: -f2)
    
    echo "📋 Connection Details:"
    echo "   Host: $HOST"
    echo "   Port: $PORT"
    echo ""
    
    echo "🔍 Step 3: Diagnosing the issue..."
    echo ""
    echo "The error 'address already in use' on port 52643 means:"
    echo "   - A previous container with name 'C.$INSTANCE_ID' still exists"
    echo "   - Or another container is using that port"
    echo ""
    
    echo "💡 Solutions (run these commands on the vast.ai host):"
    echo ""
    echo "Option 1: Remove the existing container (recommended)"
    echo "   ssh root@$HOST -p $PORT"
    echo "   docker ps -a | grep C.$INSTANCE_ID"
    echo "   docker rm -f C.$INSTANCE_ID"
    echo "   # Then restart the instance from vast.ai console"
    echo ""
    
    echo "Option 2: Check what's using the port"
    echo "   ssh root@$HOST -p $PORT"
    echo "   docker ps -a"
    echo "   netstat -tlnp | grep 52643"
    echo "   # Remove any containers using that port"
    echo ""
    
    echo "Option 3: Destroy and recreate the instance"
    echo "   $VASTAI_CMD destroy instance $INSTANCE_ID"
    echo "   # Wait a few seconds, then create a new instance"
    echo ""
    
    echo "Option 4: Let vast.ai handle it automatically"
    echo "   - Wait 5-10 minutes"
    echo "   - Vast.ai may automatically clean up old containers"
    echo "   - Then try starting the instance again from the console"
    echo ""
    
    echo "🚀 Quick Fix Script (run on vast.ai host):"
    echo "-------------------------------------------"
    cat << 'EOF'
#!/bin/bash
# Run this on the vast.ai host after SSH'ing in
CONTAINER_NAME="C.30136512"  # Replace with your container name

echo "Checking for existing containers..."
docker ps -a | grep "$CONTAINER_NAME" || echo "No container found with that name"

echo "Removing container if it exists..."
docker rm -f "$CONTAINER_NAME" 2>/dev/null && echo "✅ Removed $CONTAINER_NAME" || echo "⚠️  Container not found or already removed"

echo "Checking for containers using port 52643..."
docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Ports}}" | grep 52643 || echo "No containers using port 52643"

echo "Done! You can now restart the instance from vast.ai console."
EOF
    echo ""
    
    echo "📝 To apply the fix:"
    echo "   1. SSH into the host: ssh root@$HOST -p $PORT"
    echo "   2. Run the commands from 'Option 1' above"
    echo "   3. Go to vast.ai console and restart the instance"
    echo ""
    
else
    echo "⚠️  Could not parse SSH URL. Manual intervention required."
    echo ""
    echo "💡 Try these steps:"
    echo "   1. Check instance status: $VASTAI_CMD show instance $INSTANCE_ID"
    echo "   2. Destroy and recreate: $VASTAI_CMD destroy instance $INSTANCE_ID"
    echo "   3. Check vast.ai console: https://console.vast.ai/instances"
fi

echo ""
echo "✅ Diagnosis complete!"
