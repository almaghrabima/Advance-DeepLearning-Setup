#!/bin/bash
# Startup script to ensure SSH server is running
# This can be called by Vast.ai's onstart mechanism or run manually

set -euo pipefail

# Ensure SSH directories exist
mkdir -p /var/run/sshd
mkdir -p /root/.ssh
chmod 700 /root/.ssh 2>/dev/null || true

# Generate SSH host keys if they don't exist
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "Generating SSH host keys..."
    ssh-keygen -A 2>&1
fi

# Start SSH server if not already running
if ! pgrep -x sshd > /dev/null; then
    echo "Starting SSH server..."
    /usr/sbin/sshd -D -e &
    SSH_PID=$!
    echo "SSH server started (PID: $SSH_PID)"
    
    # Wait a moment for SSH to initialize
    sleep 2
    
    # Verify SSH is running
    if pgrep -x sshd > /dev/null; then
        echo "✅ SSH server is running on port 22"
    else
        echo "⚠️  SSH server may not have started properly"
        exit 1
    fi
else
    echo "✅ SSH server is already running"
fi

# Keep the script running (don't exit) if called directly
# This is useful when Vast.ai runs it as the main process
if [ "${1:-}" != "--daemon" ]; then
    # If not daemon mode, just start SSH and exit
    exit 0
fi

# If daemon mode, keep running
while true; do
    if ! pgrep -x sshd > /dev/null; then
        echo "SSH server died, restarting..."
        /usr/sbin/sshd -D -e &
        sleep 2
    fi
    sleep 10
done
