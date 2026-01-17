#!/usr/bin/env bash
set -euo pipefail

# Entrypoint script to clone GitHub repository
# Usage: Set GITHUB_REPO environment variable with the GitHub repository URL
# Example: GITHUB_REPO=https://github.com/user/repo.git

# Start SSH server in the background (required for Vast.ai SSH connections)
# Check if SSH is already running, if not start it
if ! pgrep -x sshd > /dev/null; then
    echo "🔧 Starting SSH server..."
    # Ensure SSH directories exist
    mkdir -p /var/run/sshd
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    
    # Generate SSH host keys if they don't exist
    if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
        echo "🔑 Generating SSH host keys..."
        ssh-keygen -A
    fi
    
    # Start SSH daemon in background (non-blocking)
    # -D: don't detach (run in foreground), but we background with &
    # -e: send output to stderr (useful for debugging)
    /usr/sbin/sshd -D -e &
    SSH_PID=$!
    echo "✅ SSH server started (PID: $SSH_PID)"
    
    # Wait a moment for SSH to initialize
    sleep 2
    
    # Verify SSH is running
    if pgrep -x sshd > /dev/null; then
        echo "✅ SSH server is running on port 22"
        # Show listening ports for debugging
        netstat -tlnp 2>/dev/null | grep :22 || ss -tlnp 2>/dev/null | grep :22 || echo "⚠️  Could not verify SSH port (netstat/ss may not be available)"
    else
        echo "⚠️  SSH server may not have started properly"
    fi
else
    echo "ℹ️  SSH server is already running"
fi

# Export environment variables to /etc/environment so they're available to all processes
# This ensures they're available even if Vast.ai's SSH setup doesn't export them
if [ -n "${GITHUB_REPO:-}" ]; then
    grep -q "^GITHUB_REPO=" /etc/environment 2>/dev/null || echo "GITHUB_REPO=${GITHUB_REPO}" >> /etc/environment
fi
if [ -n "${GITHUB_PAT:-}" ]; then
    grep -q "^GITHUB_PAT=" /etc/environment 2>/dev/null || echo "GITHUB_PAT=${GITHUB_PAT}" >> /etc/environment
fi
if [ -n "${PROJECT_REPO:-}" ]; then
    grep -q "^PROJECT_REPO=" /etc/environment 2>/dev/null || echo "PROJECT_REPO=${PROJECT_REPO}" >> /etc/environment
fi

cd /workspace

# Clone GitHub repository if GITHUB_REPO is provided
if [ -n "${GITHUB_REPO:-}" ]; then
    echo "📦 Cloning GitHub repository: ${GITHUB_REPO}"
    
    # Extract repository name from URL
    if [[ "$GITHUB_REPO" == https://github.com/* ]] || [[ "$GITHUB_REPO" == git@github.com:* ]]; then
        REPO_NAME=$(basename "${GITHUB_REPO}" .git)
    else
        REPO_NAME=$(basename "${GITHUB_REPO}" .git)
    fi
    
    # Handle authentication if GITHUB_TOKEN or GITHUB_PAT is provided
    # GITHUB_PAT takes precedence if both are set
    GITHUB_AUTH="${GITHUB_PAT:-${GITHUB_TOKEN:-}}"
    if [ -n "$GITHUB_AUTH" ]; then
        # Extract owner and repo from URL
        if [[ "$GITHUB_REPO" == https://github.com/* ]]; then
            REPO_PATH="${GITHUB_REPO#https://github.com/}"
            # Use PAT as username (GitHub accepts PAT as username with empty password)
            AUTH_REPO_URL="https://${GITHUB_AUTH}@github.com/${REPO_PATH}"
        elif [[ "$GITHUB_REPO" == git@github.com:* ]]; then
            REPO_PATH="${GITHUB_REPO#git@github.com:}"
            AUTH_REPO_URL="https://${GITHUB_AUTH}@github.com/${REPO_PATH}"
        else
            AUTH_REPO_URL="$GITHUB_REPO"
        fi
    else
        AUTH_REPO_URL="$GITHUB_REPO"
    fi
    
    # Clone or update repository
    # Disable interactive prompts for git - use multiple methods to ensure it works
    export GIT_TERMINAL_PROMPT=0
    export GIT_ASKPASS=/bin/echo
    export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no"
    
    if [ -d "$REPO_NAME/.git" ]; then
        echo "🔄 Repository exists, pulling latest changes..."
        GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/echo git -C "$REPO_NAME" pull --ff-only || true
    else
        echo "📥 Cloning repository..."
        # Disable terminal prompts and clone - redirect stdin to /dev/null to prevent password prompts
        GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/echo git clone "$AUTH_REPO_URL" "$REPO_NAME" < /dev/null 2>&1 || {
            echo "⚠️  Git clone with PAT failed, trying without authentication..."
            # Fallback: try without auth (for public repos)
            GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/echo git clone "$GITHUB_REPO" "$REPO_NAME" < /dev/null 2>&1 || echo "❌ Git clone failed"
        }
    fi
    
    echo "✅ Repository ready at: /workspace/$REPO_NAME"
    
    # Set PROJECT_REPO if not already set (for compatibility with start-project.sh)
    if [ -z "${PROJECT_REPO:-}" ]; then
        export PROJECT_REPO="$GITHUB_REPO"
    fi
fi

# Execute the original command
exec "$@"
