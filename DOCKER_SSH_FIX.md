# Docker Image SSH Fix - Root Cause Analysis

## The Problem

When using Vast.ai's **SSH launch mode**, the Docker image's `ENTRYPOINT` is **overridden** by Vast.ai. This means:
- Our `entrypoint.sh` (which starts SSH) **never runs**
- SSH server doesn't start automatically
- Connections fail with "Connection refused"

## Root Cause

From Vast.ai documentation:
> "With the SSH launch option your docker image entrypoint is not called … instead we allow you to specify an onstart script which is called as part of the new entrypoint."

So the issue is:
1. ✅ We have SSH startup code in `entrypoint.sh` - but it never runs
2. ✅ We have SSH startup code in `onstart.sh` - but it only runs if the template's onstart script calls it
3. ❌ The template's onstart script may not be configured to call `/usr/local/bin/onstart.sh`

## The Fix

### 1. Updated Docker Image

The Docker image now includes:
- ✅ `onstart.sh` - Enhanced with robust SSH startup (runs first, before anything else)
- ✅ `start-ssh.sh` - Simple standalone script to start SSH
- ✅ SSH configuration in Dockerfile (host keys, config, etc.)

### 2. Template Configuration (CRITICAL)

Your Vast.ai template **must** have an onstart script that calls our onstart.sh:

```bash
bash -c '/usr/local/bin/onstart.sh 2>&1 | tee -a /var/log/onstart.log; if [ -f /usr/local/bin/start-project.sh ]; then /usr/local/bin/start-project.sh; else start-project.sh; fi'
```

Or at minimum:
```bash
/usr/local/bin/onstart.sh
```

### 3. Rebuild and Deploy

1. **Rebuild the image:**
   ```bash
   ./build_and_push_vastai_pytorch.sh
   ```

2. **Update your Vast.ai template:**
   - Go to https://console.vast.ai/templates
   - Edit your template
   - Set **On-start Script** to the command above
   - Save the template

3. **Create a NEW instance** from the updated template
   - Old instances won't have the fix
   - Wait 2-3 minutes after instance creation

## Verification

After the instance starts, check the onstart log:

```bash
ssh -p <port> root@<host> "tail -30 /var/log/onstart.log"
```

You should see:
```
[timestamp] 🚀 Starting onstart script...
[timestamp] 🔧 Ensuring SSH server is running...
[timestamp] ✅ SSH server is running successfully (PID: ...)
```

## Why This Works

1. **Vast.ai calls the template's onstart script** when the container starts
2. **Our onstart.sh runs first** and starts SSH before doing anything else
3. **SSH is running** when Vast.ai tries to map port 22
4. **Connections work** because SSH is listening on port 22

## If It Still Doesn't Work

1. **Check the template's onstart script** - it must call `/usr/local/bin/onstart.sh`
2. **Check the onstart log** - look for SSH startup messages
3. **Manually start SSH** via web console (see QUICK_FIX_SSH.md)
4. **Verify the image** - make sure you're using `almamoha/advance-deeplearning:vastai-pytorch-automatic`

## Summary

- ✅ Docker image is fixed (onstart.sh starts SSH first)
- ⚠️  Template must be configured to call onstart.sh
- ⚠️  New instance must be created from updated template
- ✅ SSH will start automatically on new instances
