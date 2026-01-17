#!/bin/bash
# Final fix: Create .bash_profile that prevents .bashrc tmux for non-TTY

echo "🔧 Applying final fix: Creating .bash_profile wrapper..."

ssh -T vastai /bin/sh << 'FINAL_FIX' 2>&1
set -eu

# Backup existing .bash_profile if it exists
if [ -f ~/.bash_profile ]; then
    cp ~/.bash_profile ~/.bash_profile.backup.$(date +%Y%m%d_%H%M%S)
fi

# Create .bash_profile that sources .bashrc only for TTY connections
cat > ~/.bash_profile << 'BASHPROF'
# .bash_profile - sourced by login shells
# For non-TTY connections (like Cursor), skip .bashrc to avoid tmux issues
if [ -t 0 ]; then
    # We have a TTY, safe to source .bashrc
    if [ -f ~/.bashrc ]; then
        . ~/.bashrc
    fi
else
    # No TTY (like Cursor remote SSH), source .bashrc but skip tmux
    # Set a flag to prevent tmux from starting
    export SKIP_TMUX=1
    if [ -f ~/.bashrc ]; then
        # Source .bashrc but temporarily disable tmux
        BASH_SOURCE_0="$0"
        . ~/.bashrc
    fi
fi
BASHPROF

# Also modify .bashrc to check SKIP_TMUX environment variable
if [ -f ~/.bashrc ]; then
    # Add check for SKIP_TMUX at the beginning of tmux block
    if ! grep -q "SKIP_TMUX" ~/.bashrc; then
        sed -i '/# Auto-start tmux on SSH login/a\
# Skip tmux if SKIP_TMUX is set or no TTY\
if [ -n "${SKIP_TMUX:-}" ] || [ ! -t 0 ]; then\
    return\
fi
' ~/.bashrc 2>/dev/null || true
    fi
fi

echo "✅ Created .bash_profile and updated .bashrc"
FINAL_FIX

echo ""
echo "✅ Fix applied! The .bash_profile will now prevent tmux for non-TTY connections."
echo "   Try connecting with Cursor now."
