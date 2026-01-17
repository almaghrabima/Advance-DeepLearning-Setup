#!/bin/bash
# One-liner to start SSH server - copy and paste into Vast.ai web console
# This is a single command you can paste directly

mkdir -p /var/run/sshd /root/.ssh && chmod 700 /root/.ssh && [ ! -f /etc/ssh/ssh_host_rsa_key ] && ssh-keygen -A && ! pgrep -x sshd > /dev/null && /usr/sbin/sshd -D -e & sleep 3 && pgrep -x sshd && echo "✅ SSH started" || echo "⚠️ SSH status: $(pgrep -x sshd || echo 'not running')"
