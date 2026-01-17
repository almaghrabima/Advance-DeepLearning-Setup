# SSH Connection Fix for Vast.ai PyTorch Image

## Problem
Cursor remote SSH connection was failing with "Connection refused" error when connecting to Vast.ai instances using the new `vastai/pytorch` base image.

## Root Cause
The SSH server was not being started when the container launched. When Vast.ai uses SSH launch mode, it overrides the Docker image's ENTRYPOINT, so the entrypoint script that would normally start SSH wasn't running.

## Solution
Updated both `entrypoint.sh` and `onstart.sh` to:
1. Check if SSH server is already running
2. Generate SSH host keys if they don't exist
3. Start SSH daemon in the background
4. Verify SSH is running and listening on port 22

## Changes Made

### entrypoint.sh
- Added SSH server startup logic at the beginning
- Generates SSH host keys if missing
- Starts `sshd -D -e &` in background
- Verifies SSH is running before proceeding

### onstart.sh
- Added SSH server startup logic at the beginning
- Same SSH startup logic as entrypoint
- Logs all SSH startup activities

## Next Steps

1. **Rebuild the Docker image:**
   ```bash
   ./build_and_push_vastai_pytorch.sh
   ```

2. **Update your Vast.ai template** to use the new image:
   - Image: `almamoha/advance-deeplearning:vastai-pytorch-automatic`
   - Launch Mode: SSH (Interactive shell server, SSH)
   - On-start Script: Should reference `/usr/local/bin/onstart.sh` or include the SSH startup logic

3. **Create a new instance** from the updated template

4. **Test the connection** with Cursor remote SSH

## Verification

After the instance starts, you can verify SSH is running by:
```bash
ssh vastai "pgrep -x sshd && echo 'SSH is running' || echo 'SSH not running'"
```

Or check the onstart log:
```bash
ssh vastai "tail -20 /var/log/onstart.log"
```

## Notes

- The SSH server starts in the background using `sshd -D -e &`
- The `-D` flag prevents detaching (runs in foreground), but we background it with `&`
- The `-e` flag sends output to stderr for better debugging
- Both entrypoint and onstart scripts now handle SSH startup to cover all launch modes
