#!/usr/bin/env bash
# Diagnose SSH connection issues on Vast.ai instance
# Usage: ./diagnose_ssh_vastai.sh [host] [port]

set -euo pipefail

HOST="${1:-}"
PORT="${2:-}"
SSH_KEY="${VAST_SSH_KEY:-$HOME/.ssh/vastai}"

if [ -z "$HOST" ] || [ -z "$PORT" ]; then
    echo "❌ Usage: $0 <host> <port>"
    echo ""
    echo "Example:"
    echo "   $0 174.91.229.149 52407"
    echo ""
    echo "Or set via SSH config 'vastai' host:"
    echo "   $0"
    exit 1
fi

echo "🔍 Diagnosing SSH Connection Issues"
echo "===================================="
echo "Host: $HOST"
echo "Port: $PORT"
echo ""

# Test 1: Basic connectivity
echo "1️⃣ Testing basic network connectivity..."
if timeout 3 bash -c "echo > /dev/tcp/$HOST/$PORT" 2>/dev/null; then
    echo "   ✅ Port $PORT is reachable"
else
    echo "   ❌ Port $PORT is NOT reachable (connection refused or timeout)"
    echo "   💡 This suggests:"
    echo "      - Instance may not be fully started"
    echo "      - SSH server is not running"
    echo "      - Firewall blocking the port"
    exit 1
fi
echo ""

# Test 2: SSH connection
echo "2️⃣ Testing SSH connection..."
SSH_CMD="ssh -i \"$SSH_KEY\" -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes -p $PORT root@$HOST"

if $SSH_CMD 'echo "SSH connection successful"' 2>&1 | grep -q "SSH connection successful"; then
    echo "   ✅ SSH connection works!"
    CAN_CONNECT=true
else
    echo "   ❌ SSH connection failed"
    CAN_CONNECT=false
    echo ""
    echo "   Trying to get more details..."
    $SSH_CMD 'echo "test"' 2>&1 | head -5
fi
echo ""

if [ "$CAN_CONNECT" = true ]; then
    # Test 3: Check SSH server status
    echo "3️⃣ Checking SSH server status on remote instance..."
    SSH_STATUS=$($SSH_CMD '/bin/sh -c "pgrep -x sshd > /dev/null && echo RUNNING || echo NOT_RUNNING; ps aux | grep sshd | grep -v grep | head -2 || true"' 2>&1)
    echo "$SSH_STATUS" | while IFS= read -r line; do
        if echo "$line" | grep -q "RUNNING"; then
            echo "   ✅ SSH server (sshd) is running"
        elif echo "$line" | grep -q "NOT_RUNNING"; then
            echo "   ❌ SSH server (sshd) is NOT running"
        elif echo "$line" | grep -q "sshd"; then
            echo "   📋 $line"
        fi
    done
    echo ""
    
    # Test 4: Check SSH port listening
    echo "4️⃣ Checking if SSH is listening on port 22..."
    PORT_CHECK=$($SSH_CMD '/bin/sh -c "netstat -tlnp 2>/dev/null | grep :22 || ss -tlnp 2>/dev/null | grep :22 || echo NO_LISTEN_TOOLS"' 2>&1)
    if echo "$PORT_CHECK" | grep -q ":22"; then
        echo "   ✅ SSH is listening on port 22"
        echo "   $PORT_CHECK"
    elif echo "$PORT_CHECK" | grep -q "NO_LISTEN_TOOLS"; then
        echo "   ⚠️  Cannot check (netstat/ss not available)"
    else
        echo "   ❌ SSH is NOT listening on port 22"
    fi
    echo ""
    
    # Test 5: Check Docker image
    echo "5️⃣ Checking Docker image and container info..."
    IMAGE_INFO=$($SSH_CMD '/bin/sh -c "cat /etc/os-release 2>/dev/null | head -3; echo ---; docker ps 2>/dev/null | head -3 || echo No docker info"' 2>&1)
    echo "$IMAGE_INFO"
    echo ""
    
    # Test 6: Check onstart log
    echo "6️⃣ Checking onstart script log..."
    ONSTART_LOG=$($SSH_CMD 'tail -30 /var/log/onstart.log 2>/dev/null || echo "No onstart.log found"' 2>&1)
    if echo "$ONSTART_LOG" | grep -q "SSH server"; then
        echo "   ✅ Found SSH-related entries in onstart.log:"
        echo "$ONSTART_LOG" | grep -i ssh | head -5
    else
        echo "   ⚠️  onstart.log contents:"
        echo "$ONSTART_LOG" | head -10
    fi
    echo ""
    
    # Test 7: Try to manually start SSH
    echo "7️⃣ Attempting to diagnose/fix SSH..."
    echo "   Checking if SSH can be started..."
    FIX_ATTEMPT=$($SSH_CMD '/bin/sh <<EOF
        # Check if sshd exists
        if ! command -v sshd > /dev/null 2>&1; then
            echo "❌ sshd command not found"
            exit 1
        fi
        
        # Check if SSH keys exist
        if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
            echo "⚠️  SSH host keys missing, generating..."
            mkdir -p /var/run/sshd
            ssh-keygen -A 2>&1 || echo "Failed to generate keys"
        fi
        
        # Check if sshd is running
        if ! pgrep -x sshd > /dev/null; then
            echo "⚠️  Starting SSH server..."
            mkdir -p /var/run/sshd
            /usr/sbin/sshd -D -e &
            sleep 2
            if pgrep -x sshd > /dev/null; then
                echo "✅ SSH server started"
            else
                echo "❌ Failed to start SSH server"
            fi
        else
            echo "✅ SSH server already running"
        fi
EOF
' 2>&1)
    echo "$FIX_ATTEMPT"
    echo ""
    
    echo "📋 Summary and Recommendations:"
    echo "==============================="
    echo ""
    echo "If SSH was not running, it should now be started."
    echo "Try connecting with Cursor again."
    echo ""
    echo "If issues persist:"
    echo "1. Verify the instance is using the updated image:"
    echo "   almamoha/advance-deeplearning:vastai-pytorch-automatic"
    echo ""
    echo "2. Check Vast.ai template settings:"
    echo "   - Launch Mode should be 'SSH'"
    echo "   - On-start Script should include SSH startup"
    echo ""
    echo "3. Rebuild and redeploy the image if needed:"
    echo "   ./build_and_push_vastai_pytorch.sh"
else
    echo "📋 Cannot connect to diagnose further."
    echo ""
    echo "Possible issues:"
    echo "1. Instance is still starting (wait a few minutes)"
    echo "2. Wrong host/port"
    echo "3. SSH key not authorized"
    echo "4. Instance crashed or stopped"
    echo ""
    echo "Try connecting manually:"
    echo "   ssh -i $SSH_KEY -p $PORT root@$HOST"
fi
