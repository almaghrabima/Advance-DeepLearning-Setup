#!/usr/bin/env bash
# Fix SSH on Vast.ai instance by executing commands via Vast.ai API
# This script uses Vast.ai's exec command to start SSH inside the container

set -euo pipefail

INSTANCE_ID="${1:-30139641}"
VASTAI_CMD="${VASTAI_CMD:-/opt/homebrew/bin/vastai}"

echo "🔧 Fixing SSH on Vast.ai Instance via API"
echo "=========================================="
echo "Instance ID: $INSTANCE_ID"
echo ""

# Check instance status
echo "1️⃣ Checking instance status..."
STATUS=$($VASTAI_CMD show instance $INSTANCE_ID 2>&1)
if echo "$STATUS" | grep -qi "running"; then
    echo "   ✅ Instance is running"
else
    echo "   ❌ Instance is not running. Status:"
    echo "$STATUS" | grep -i "status" || echo "$STATUS" | head -5
    echo ""
    echo "   Please start the instance first:"
    echo "   $VASTAI_CMD start instance $INSTANCE_ID"
    exit 1
fi
echo ""

# Get SSH connection info
SSH_HOST=$(echo "$STATUS" | grep "SSH Addr" | awk '{print $NF}' | head -1)
SSH_PORT=$(echo "$STATUS" | grep "SSH Port" | awk '{print $NF}' | head -1)

echo "2️⃣ Instance Details:"
echo "   SSH Host: ${SSH_HOST:-unknown}"
echo "   SSH Port: ${SSH_PORT:-unknown}"
echo ""

# Try to execute command via Vast.ai exec
echo "3️⃣ Attempting to start SSH server inside container..."
echo "   (This requires Vast.ai API access)"
echo ""

# Check if we can use vastai exec
if $VASTAI_CMD exec $INSTANCE_ID "echo 'Connection test'" 2>&1 | grep -q "Connection test"; then
    echo "   ✅ Can execute commands via Vast.ai API"
    echo ""
    
    echo "4️⃣ Starting SSH server..."
    
    # Start SSH server command
    SSH_START_CMD='
    mkdir -p /var/run/sshd /root/.ssh
    chmod 700 /root/.ssh 2>/dev/null || true
    if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
        echo "Generating SSH host keys..."
        ssh-keygen -A 2>&1
    fi
    if ! pgrep -x sshd > /dev/null; then
        echo "Starting SSH server..."
        /usr/sbin/sshd -D -e &
        sleep 3
        if pgrep -x sshd > /dev/null; then
            echo "✅ SSH server started successfully"
            pgrep -x sshd
        else
            echo "❌ Failed to start SSH server"
            exit 1
        fi
    else
        echo "✅ SSH server already running"
        pgrep -x sshd
    fi
    '
    
    if $VASTAI_CMD exec $INSTANCE_ID "$SSH_START_CMD" 2>&1; then
        echo ""
        echo "   ✅ SSH server should now be running"
        echo ""
        echo "5️⃣ Waiting 5 seconds, then testing connection..."
        sleep 5
        
        if ssh -o ConnectTimeout=5 -o BatchMode=yes -p ${SSH_PORT:-52221} root@${SSH_HOST:-174.91.229.149} "pgrep -x sshd" 2>&1 | grep -q "[0-9]"; then
            echo "   ✅ SSH connection successful!"
            echo ""
            echo "🎉 You can now connect with Cursor!"
        else
            echo "   ⚠️  SSH may still be starting. Try connecting in a few seconds."
        fi
    else
        echo "   ❌ Failed to start SSH server via API"
        echo ""
        echo "   Alternative: Use Vast.ai web console"
        echo "   1. Go to https://console.vast.ai"
        echo "   2. Find instance $INSTANCE_ID"
        echo "   3. Click 'Open Terminal' or 'Console'"
        echo "   4. Run the commands manually (see below)"
    fi
else
    echo "   ⚠️  Cannot execute commands via Vast.ai API"
    echo ""
    echo "   Alternative Solutions:"
    echo ""
    echo "   Option 1: Use Vast.ai Web Console"
    echo "   =================================="
    echo "   1. Go to https://console.vast.ai/instances"
    echo "   2. Find instance $INSTANCE_ID"
    echo "   3. Click 'Open Terminal' or 'Console' button"
    echo "   4. Run these commands:"
    echo ""
    cat << 'MANUAL_FIX'
      mkdir -p /var/run/sshd /root/.ssh
      chmod 700 /root/.ssh
      if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
          ssh-keygen -A
      fi
      if ! pgrep -x sshd > /dev/null; then
          /usr/sbin/sshd -D -e &
          sleep 2
      fi
      pgrep -x sshd && echo "SSH is running" || echo "SSH failed to start"
MANUAL_FIX
    echo ""
    echo "   Option 2: Restart Instance"
    echo "   ========================="
    echo "   Sometimes restarting helps:"
    echo "   $VASTAI_CMD stop instance $INSTANCE_ID"
    echo "   # Wait 10 seconds"
    echo "   $VASTAI_CMD start instance $INSTANCE_ID"
    echo "   # Wait 2-3 minutes for instance to fully start"
    echo ""
    echo "   Option 3: Check Template Onstart Script"
    echo "   ======================================="
    echo "   The template may not have the correct onstart script."
    echo "   Update it to include SSH startup (see FIX_SSH_CONNECTION.md)"
fi

echo ""
echo "📋 Next Steps:"
echo "============="
echo ""
echo "1. If SSH is now running, try connecting with Cursor"
echo "2. If not, use Vast.ai web console to start SSH manually"
echo "3. Update your template's onstart script to auto-start SSH"
echo "4. Create a new instance from the updated template"
