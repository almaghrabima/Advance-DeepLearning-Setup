# Fix SSH Connection for Vast.ai PyTorch Image

## Current Issue
Cursor remote SSH connection fails with "Connection refused" error.

## Root Cause
The SSH server is not running on the instance. This can happen because:
1. The instance is using an old image (before SSH fixes)
2. The Vast.ai template's onstart script isn't configured to start SSH
3. The onstart script isn't being executed

## Solution Steps

### Step 1: Rebuild the Docker Image
First, ensure you've built the image with the SSH fixes:

```bash
./build_and_push_vastai_pytorch.sh
```

This creates: `almamoha/advance-deeplearning:vastai-pytorch-automatic`

### Step 2: Update/Create Vast.ai Template

The template **must** have an onstart command that runs the onstart script. 

#### Option A: Update Existing Template via API

If you know your template hash/ID:

```bash
# Get your template hash first
vastai show templates

# Update the template with correct onstart command
vastai update template <template_hash> \
  --image almamoha/advance-deeplearning:vastai-pytorch-automatic \
  --onstart-cmd "bash -c '/usr/local/bin/onstart.sh 2>&1 | tee -a /var/log/onstart.log; if [ -f /usr/local/bin/start-project.sh ]; then /usr/local/bin/start-project.sh; else start-project.sh; fi'"
```

#### Option B: Create New Template via UI

1. Go to [Vast.ai Console](https://console.vast.ai) → Templates
2. Create new template or edit existing one
3. Set **Image**: `almamoha/advance-deeplearning:vastai-pytorch-automatic`
4. Set **Launch Mode**: `SSH` (Interactive shell server, SSH)
5. Set **On-start Script** to:
   ```bash
   bash -c '/usr/local/bin/onstart.sh 2>&1 | tee -a /var/log/onstart.log; if [ -f /usr/local/bin/start-project.sh ]; then /usr/local/bin/start-project.sh; else start-project.sh; fi'
   ```
6. Save the template

### Step 3: Create New Instance

**Important**: You must create a **NEW** instance from the updated template. Old instances won't have the fixes.

```bash
vastai create instance <template_hash> --price <price>
```

Or use the Vast.ai UI to create a new instance from the template.

### Step 4: Wait for Instance to Start

Wait 2-3 minutes for the instance to fully start and the onstart script to run.

### Step 5: Diagnose Connection

Use the diagnostic script to check SSH status:

```bash
# Get SSH connection details from Vast.ai
vastai ssh-url <instance_id>

# Run diagnostic (replace with actual host and port)
./diagnose_ssh_vastai.sh <host> <port>
```

Or manually test:

```bash
# Test basic SSH connection
ssh -p <port> root@<host> "pgrep -x sshd && echo 'SSH running' || echo 'SSH NOT running'"

# Check onstart log
ssh -p <port> root@<host> "tail -30 /var/log/onstart.log"
```

### Step 6: If SSH Still Not Running

If SSH is still not running after the onstart script, manually start it:

```bash
ssh -p <port> root@<host> << 'EOF'
# Start SSH server
mkdir -p /var/run/sshd
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    ssh-keygen -A
fi
/usr/sbin/sshd -D -e &
sleep 2
pgrep -x sshd && echo "SSH started" || echo "SSH failed to start"
EOF
```

Then try connecting with Cursor again.

## Verification Checklist

- [ ] Image rebuilt: `docker pull almamoha/advance-deeplearning:vastai-pytorch-automatic`
- [ ] Template updated with correct onstart command
- [ ] New instance created from updated template
- [ ] Instance fully started (wait 2-3 minutes)
- [ ] SSH server running: `pgrep -x sshd` returns PID
- [ ] SSH listening on port 22: `netstat -tlnp | grep :22` or `ss -tlnp | grep :22`
- [ ] onstart.log shows SSH startup: `grep -i ssh /var/log/onstart.log`

## Common Issues

### Issue: "Connection refused" persists
**Solution**: 
1. Verify instance is using the new image
2. Check onstart.log to see if script ran
3. Manually start SSH (see Step 6 above)

### Issue: Template doesn't have onstart field
**Solution**: 
- Use Vast.ai API to update template
- Or create template via API with onstart command

### Issue: onstart script not found
**Solution**: 
- Verify image was built correctly
- Check: `docker run --rm almamoha/advance-deeplearning:vastai-pytorch-automatic ls -la /usr/local/bin/onstart.sh`

## Quick Fix Script

If you can connect via regular SSH but Cursor fails, run this on the instance:

```bash
ssh -p <port> root@<host> << 'EOF'
# Ensure SSH is running
if ! pgrep -x sshd > /dev/null; then
    mkdir -p /var/run/sshd
    [ ! -f /etc/ssh/ssh_host_rsa_key ] && ssh-keygen -A
    /usr/sbin/sshd -D -e &
    sleep 2
fi
pgrep -x sshd && echo "✅ SSH is running" || echo "❌ SSH failed"
EOF
```

## Next Steps After Fix

Once SSH is working:
1. Test Cursor connection
2. If tmux auto-start interferes, use `fix_vastai_for_cursor.sh`
3. Verify your project repository is cloned in `/workspace`
