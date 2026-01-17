#!/bin/bash
# Onstart script for Vast.ai instances
# This script runs when the container starts and ensures the repository is cloned
# Output is logged to /var/log/onstart.log

set -euo pipefail

# Log file
LOG_FILE="/var/log/onstart.log"
mkdir -p "$(dirname "$LOG_FILE")"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "🚀 Starting onstart script..."

# CRITICAL: Start SSH server FIRST (before anything else)
# This is essential for Vast.ai SSH launch mode to work
# Vast.ai overrides the Docker entrypoint, so SSH must start here
log "🔧 Ensuring SSH server is running (critical for Vast.ai connections)..."

# Ensure SSH directories exist
mkdir -p /var/run/sshd
mkdir -p /root/.ssh
chmod 700 /root/.ssh 2>/dev/null || true

# Generate SSH host keys if they don't exist (required for sshd to start)
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    log "🔑 Generating SSH host keys (required for SSH server)..."
    ssh-keygen -A 2>&1 | tee -a "$LOG_FILE" || {
        log "❌ Failed to generate SSH host keys"
        # Try alternative method
        mkdir -p /etc/ssh
        ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N "" 2>&1 | tee -a "$LOG_FILE" || true
        ssh-keygen -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -N "" 2>&1 | tee -a "$LOG_FILE" || true
        ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N "" 2>&1 | tee -a "$LOG_FILE" || true
    }
fi

# Check if SSH is already running
if pgrep -x sshd > /dev/null; then
    log "ℹ️  SSH server is already running (PID: $(pgrep -x sshd))"
else
    log "🚀 Starting SSH server daemon..."
    
    # Start SSH daemon in background
    # -D: don't detach (run in foreground), but we background with &
    # -e: send output to stderr (useful for debugging)
    # -f: specify config file (optional, uses default)
    /usr/sbin/sshd -D -e 2>&1 | tee -a "$LOG_FILE" &
    SSH_PID=$!
    log "✅ SSH server start command executed (PID: $SSH_PID)"
    
    # Wait for SSH to initialize
    sleep 3
    
    # Verify SSH is running
    if pgrep -x sshd > /dev/null; then
        log "✅ SSH server is running successfully (PID: $(pgrep -x sshd))"
        # Show listening ports for debugging
        if command -v netstat > /dev/null 2>&1; then
            netstat -tlnp 2>/dev/null | grep :22 | tee -a "$LOG_FILE" || true
        elif command -v ss > /dev/null 2>&1; then
            ss -tlnp 2>/dev/null | grep :22 | tee -a "$LOG_FILE" || true
        else
            log "⚠️  Cannot verify SSH port (netstat/ss not available)"
        fi
    else
        log "❌ SSH server failed to start!"
        log "Attempting to diagnose..."
        # Try to see what went wrong
        /usr/sbin/sshd -T 2>&1 | head -10 | tee -a "$LOG_FILE" || true
        log "⚠️  SSH server is not running - connections will fail!"
        log "⚠️  You may need to start it manually or check configuration"
    fi
fi

# Source environment variables from /etc/environment if they exist
if [ -f /etc/environment ]; then
    set -a
    source /etc/environment
    set +a
    log "✅ Loaded environment variables from /etc/environment"
fi

# Also try to get environment variables from the container's main process
if [ -f /proc/1/environ ]; then
    while IFS= read -r -d '' line; do
        if [[ "$line" == GITHUB_* ]] || [[ "$line" == PROJECT_REPO=* ]]; then
            export "$line"
        fi
    done < /proc/1/environ
    log "✅ Loaded environment variables from container process"
fi

# Set default GITHUB_REPO from PROJECT_REPO if not set
if [ -z "${GITHUB_REPO:-}" ] && [ -n "${PROJECT_REPO:-}" ]; then
    export GITHUB_REPO="${PROJECT_REPO}"
    log "ℹ️  Using PROJECT_REPO as GITHUB_REPO: ${GITHUB_REPO}"
fi

# Clone repository using entrypoint logic or directly
if [ -f /usr/local/bin/entrypoint.sh ]; then
    log "📦 Running entrypoint script to clone repository..."
    
    # Export variables for entrypoint
    export GIT_TERMINAL_PROMPT=0
    
    # Run entrypoint with a dummy command (it will clone and then exec the command)
    # We use 'true' as the command so it doesn't try to run start-project.sh
    if /usr/local/bin/entrypoint.sh true 2>&1 | tee -a "$LOG_FILE"; then
        log "✅ Entrypoint script completed successfully"
    else
        EXIT_CODE=$?
        log "⚠️  Entrypoint script exited with code $EXIT_CODE, trying direct clone..."
        
        # Fallback: Clone directly if entrypoint failed
        if [ -n "${GITHUB_REPO:-}" ]; then
            REPO_NAME=$(basename "${GITHUB_REPO}" .git)
            cd /workspace
            
            if [ -d "$REPO_NAME/.git" ]; then
                log "🔄 Repository exists, pulling latest changes..."
                GIT_TERMINAL_PROMPT=0 git -C "$REPO_NAME" pull --ff-only 2>&1 | tee -a "$LOG_FILE" || true
            else
                log "📥 Cloning repository directly..."
                GITHUB_AUTH="${GITHUB_PAT:-${GITHUB_TOKEN:-}}"
                if [ -n "$GITHUB_AUTH" ]; then
                    REPO_PATH="${GITHUB_REPO#https://github.com/}"
                    AUTH_REPO_URL="https://${GITHUB_AUTH}@github.com/${REPO_PATH}"
                    export GIT_TERMINAL_PROMPT=0
                    export GIT_ASKPASS=/bin/echo
                    GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/echo git clone "$AUTH_REPO_URL" "$REPO_NAME" < /dev/null 2>&1 | tee -a "$LOG_FILE" || {
                        log "⚠️  Git clone with PAT failed, trying without authentication..."
                        GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/echo git clone "$GITHUB_REPO" "$REPO_NAME" < /dev/null 2>&1 | tee -a "$LOG_FILE" || log "❌ Git clone failed"
                    }
                else
                    export GIT_TERMINAL_PROMPT=0
                    export GIT_ASKPASS=/bin/echo
                    GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/echo git clone "$GITHUB_REPO" "$REPO_NAME" < /dev/null 2>&1 | tee -a "$LOG_FILE" || log "❌ Git clone failed"
                fi
            fi
        fi
    fi
else
    log "⚠️  Entrypoint script not found at /usr/local/bin/entrypoint.sh"
fi

# Verify repository was cloned
cd /workspace || exit 1

if [ -n "${GITHUB_REPO:-}" ]; then
    REPO_NAME=$(basename "${GITHUB_REPO}" .git)
    
    if [ -d "$REPO_NAME/.git" ]; then
        log "✅ Repository '$REPO_NAME' exists at /workspace/$REPO_NAME"
        log "📋 Repository info:"
        cd "$REPO_NAME" && git remote -v 2>&1 | tee -a "$LOG_FILE" || true
        cd /workspace
    else
        log "❌ Repository '$REPO_NAME' not found at /workspace/$REPO_NAME"
        log "   GITHUB_REPO: ${GITHUB_REPO}"
        log "   GITHUB_PAT: ${GITHUB_PAT:+SET (hidden)}"
    fi
else
    log "⚠️  GITHUB_REPO not set, skipping repository clone"
fi

log "✅ Onstart script completed"
log "📝 Full log available at: $LOG_FILE"
