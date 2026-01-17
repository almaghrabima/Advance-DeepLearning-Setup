# Quick Fix: Start SSH on Vast.ai Instance

## Problem
SSH connection refused - SSH server is not running inside the Docker container.

## Solution: Use Vast.ai Web Console

### Step 1: Open Web Console
1. Go to: **https://console.vast.ai/instances**
2. Find your instance (ID: 30139641)
3. Look for **"Open Terminal"**, **"Console"**, **"Web Terminal"**, or **"SSH Terminal"** button
4. Click it to open a browser-based terminal

### Step 2: Start SSH Server
Copy and paste this **entire command** into the terminal:

```bash
mkdir -p /var/run/sshd /root/.ssh && chmod 700 /root/.ssh && [ ! -f /etc/ssh/ssh_host_rsa_key ] && ssh-keygen -A && ! pgrep -x sshd > /dev/null && /usr/sbin/sshd -D -e & sleep 3 && pgrep -x sshd && echo "✅ SSH started successfully!" || echo "⚠️ SSH may already be running or failed to start"
```

### Step 3: Verify SSH Started
After running the command, you should see:
- Either: `✅ SSH started successfully!` with a process ID
- Or: `⚠️ SSH may already be running or failed to start`

### Step 4: Test Connection
Wait 5 seconds, then try your SSH command again:

```bash
ssh -i /Users/mohammedalmaghrabi/.ssh/vastai -p 52432 root@174.91.229.149 -L 8080:localhost:8080
```

Or test with Cursor remote SSH.

## Alternative: Multi-line Commands (Easier to Debug)

If the one-liner doesn't work, try these commands one by one:

```bash
# 1. Create directories
mkdir -p /var/run/sshd /root/.ssh
chmod 700 /root/.ssh

# 2. Generate SSH keys if needed
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "Generating SSH host keys..."
    ssh-keygen -A
fi

# 3. Check if SSH is already running
if pgrep -x sshd > /dev/null; then
    echo "SSH is already running"
    pgrep -x sshd
else
    echo "Starting SSH server..."
    /usr/sbin/sshd -D -e &
    sleep 3
    
    # 4. Verify it started
    if pgrep -x sshd > /dev/null; then
        echo "✅ SSH server started!"
        echo "Process ID: $(pgrep -x sshd)"
    else
        echo "❌ Failed to start SSH"
        echo "Trying to see errors..."
        /usr/sbin/sshd -T 2>&1 | head -5
    fi
fi

# 5. Check if listening on port 22
echo ""
echo "Checking if SSH is listening..."
netstat -tlnp 2>/dev/null | grep :22 || ss -tlnp 2>/dev/null | grep :22 || echo "Cannot verify (tools not available)"
```

## Why This Happens

The Docker image has SSH startup code in `entrypoint.sh` and `onstart.sh`, but:
1. Vast.ai's SSH launch mode may override the entrypoint
2. The onstart script may not be configured in your template
3. The onstart script may have failed to run

## Permanent Fix

After you get SSH working, update your Vast.ai template:

1. Go to **https://console.vast.ai/templates**
2. Find your template
3. Edit it and set the **On-start Script** to:
   ```bash
   bash -c '/usr/local/bin/onstart.sh 2>&1 | tee -a /var/log/onstart.log; if [ -f /usr/local/bin/start-project.sh ]; then /usr/local/bin/start-project.sh; else start-project.sh; fi'
   ```
4. Save the template
5. Create a new instance from the updated template

This ensures SSH starts automatically on future instances.

## Check Onstart Log

If you want to see why SSH didn't start automatically:

```bash
# In the web console, run:
tail -50 /var/log/onstart.log
```

Look for SSH-related messages or errors.
