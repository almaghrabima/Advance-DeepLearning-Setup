#!/bin/bash
# Startup script for Vast.ai - ensures SSH and services start
# This script is called by Vast.ai in Jupyter/SSH launch modes

set -euo pipefail

# Start SSH server first (critical for connections)
echo "Starting SSH server..."
/usr/local/bin/start-ssh.sh || {
    echo "Failed to start SSH via start-ssh.sh, trying direct method..."
    mkdir -p /var/run/sshd /root/.ssh
    chmod 700 /root/.ssh 2>/dev/null || true
    [ ! -f /etc/ssh/ssh_host_rsa_key ] && ssh-keygen -A
    if ! pgrep -x sshd > /dev/null; then
        /usr/sbin/sshd -D -e &
        sleep 2
    fi
}

# Run onstart script if it exists (clones repo, etc.)
if [ -f /usr/local/bin/onstart.sh ]; then
    echo "Running onstart script..."
    /usr/local/bin/onstart.sh || echo "Onstart script completed with warnings"
fi

# Keep container running
# In Jupyter mode, Vast.ai will start Jupyter
# In SSH mode, we just keep SSH running
exec tail -f /dev/null
