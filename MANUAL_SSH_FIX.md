# Manual SSH Fix for Vast.ai Instance

## Current Problem
SSH server is not running inside the Docker container, so Cursor cannot connect.

## Solution: Use Vast.ai Web Console

Since we can't SSH in, we'll use Vast.ai's web console to start SSH manually.

### Step 1: Access Vast.ai Web Console

1. Go to https://console.vast.ai/instances
2. Find your instance (ID: 30139641)
3. Look for one of these buttons:
   - **"Open Terminal"**
   - **"Console"**
   - **"Web Terminal"**
   - **"SSH Terminal"**
4. Click it to open a terminal in your browser

### Step 2: Start SSH Server

Once you have terminal access, run these commands:

```bash
# Create necessary directories
mkdir -p /var/run/sshd /root/.ssh
chmod 700 /root/.ssh

# Generate SSH host keys if they don't exist
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "Generating SSH host keys..."
    ssh-keygen -A
fi

# Check if SSH is already running
if pgrep -x sshd > /dev/null; then
    echo "SSH is already running"
    pgrep -x sshd
else
    echo "Starting SSH server..."
    /usr/sbin/sshd -D -e &
    sleep 3
    
    # Verify SSH started
    if pgrep -x sshd > /dev/null; then
        echo "✅ SSH server started successfully!"
        echo "Process ID: $(pgrep -x sshd)"
    else
        echo "❌ Failed to start SSH server"
        echo "Checking for errors..."
        /usr/sbin/sshd -T 2>&1 | head -10
    fi
fi

# Verify SSH is listening on port 22
echo ""
echo "Checking if SSH is listening..."
netstat -tlnp 2>/dev/null | grep :22 || ss -tlnp 2>/dev/null | grep :22 || echo "Cannot verify (netstat/ss not available)"
```

### Step 3: Test Connection

After running the commands above, try connecting with Cursor again.

If it still doesn't work, check the onstart log:

```bash
tail -50 /var/log/onstart.log
```

Look for any SSH-related errors.

## Alternative: Restart Instance

If you can't access the web console, try restarting the instance:

1. Go to https://console.vast.ai/instances
2. Find instance 30139641
3. Click **"Stop"** or **"Restart"**
4. Wait 2-3 minutes
5. Click **"Start"** (if you stopped it)
6. Wait another 2-3 minutes for the instance to fully start
7. Try connecting again

**Note**: This will only work if your template's onstart script is configured to start SSH.

## Permanent Fix: Update Template

To prevent this from happening again, you need to ensure your Vast.ai template has the correct onstart script.

### Check Current Template

1. Go to https://console.vast.ai/templates
2. Find your template
3. Check the **"On-start Script"** or **"Onstart Command"** field

### Update Template Onstart Script

The onstart script should include SSH startup. It should look like this:

```bash
bash -c '/usr/local/bin/onstart.sh 2>&1 | tee -a /var/log/onstart.log; if [ -f /usr/local/bin/start-project.sh ]; then /usr/local/bin/start-project.sh; else start-project.sh; fi'
```

Or if you're setting it directly in the template, make sure `/usr/local/bin/onstart.sh` is being called, which should start SSH (we updated it earlier).

### Verify Image Has SSH Startup

The image `almamoha/advance-deeplearning:vastai-pytorch-automatic` should have:
- `/usr/local/bin/onstart.sh` - which starts SSH
- `/usr/local/bin/entrypoint.sh` - which also starts SSH

Both scripts now include SSH startup code.

## Quick Verification Commands

Once SSH is running, you can verify with:

```bash
# Check if SSH process is running
pgrep -x sshd

# Check if SSH is listening
netstat -tlnp | grep :22
# or
ss -tlnp | grep :22

# Check onstart log for SSH messages
grep -i ssh /var/log/onstart.log
```

## If Nothing Works

1. **Destroy the instance and create a new one** from an updated template
2. Make sure the template has the correct onstart script
3. Wait 3-5 minutes after instance creation for everything to start
4. Then try connecting

## Summary

**Immediate fix**: Use Vast.ai web console → Open Terminal → Run SSH startup commands

**Permanent fix**: Update template's onstart script to call `/usr/local/bin/onstart.sh` which starts SSH automatically
