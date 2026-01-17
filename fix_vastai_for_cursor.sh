#!/bin/bash
# Script to fix VastAI instance for Cursor remote SSH connection
# This disables tmux auto-start for non-interactive connections

set -euo pipefail

echo "🔧 Fixing VastAI instance for Cursor remote SSH..."
echo ""
echo "This script will:"
echo "  1. Modify .bashrc to skip tmux for non-TTY connections (like Cursor)"
echo "  2. Create ~/.no_auto_tmux file as backup"
echo ""

# Execute fix script directly via SSH using /bin/sh to bypass .bashrc
echo "📝 Executing fix on remote server (using /bin/sh to bypass .bashrc)..."

# Pipe the script directly to ssh with /bin/sh
ssh -T vastai /bin/sh << 'REMOTE_FIX' 2>&1 | grep -v "can't find session\|open terminal failed" || true
set -eu
cd ~

# Create backup
if [ -f ~/.bashrc ]; then
    cp ~/.bashrc ~/.bashrc.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
    echo "✅ Created backup"
fi

# Create .no_auto_tmux file  
touch ~/.no_auto_tmux 2>/dev/null || true
echo "✅ Created ~/.no_auto_tmux"

# Modify .bashrc to add TTY check to tmux condition
if [ -f ~/.bashrc ]; then
    if grep -q "\[ -t 0 \]" ~/.bashrc 2>/dev/null && grep -q "# Auto-start tmux" ~/.bashrc 2>/dev/null; then
        echo "ℹ️  .bashrc already modified with TTY check"
    else
        # Create a modified version of .bashrc
        TMP_BASHRC=$(mktemp)
        MODIFIED=0
        
        while IFS= read -r line; do
            # Check if this is the tmux condition line and doesn't already have TTY check
            if echo "$line" | grep -q '\$PS1' && echo "$line" | grep -q 'screen' && ! echo "$line" | grep -q '\-t 0'; then
                # Add TTY check: [ -n "$PS1" ] becomes [ -n "$PS1" ] && [ -t 0 ]
                NEW_LINE=$(echo "$line" | sed 's/\[ -n "\$PS1" \]/[ -n "$PS1" ] \&\& [ -t 0 ]/')
                echo "$NEW_LINE" >> "$TMP_BASHRC"
                MODIFIED=1
            else
                echo "$line" >> "$TMP_BASHRC"
            fi
        done < ~/.bashrc
        
        if [ $MODIFIED -eq 1 ]; then
            mv "$TMP_BASHRC" ~/.bashrc
            echo "✅ Modified .bashrc to require TTY for tmux"
        else
            # Fallback: Comment out exec tmux line
            rm -f "$TMP_BASHRC"
            sed -i 's/exec tmux attach-session -t main/# exec tmux attach-session -t main  # Disabled for non-TTY/' ~/.bashrc 2>/dev/null && echo "✅ Commented out tmux exec line" || echo "⚠️  Could not modify .bashrc"
        fi
    fi
fi

echo "✅ Fix completed!"
REMOTE_FIX

echo ""
echo "✅ Remote server fixed!"
echo ""
echo "Now try connecting with Cursor remote SSH extension."
