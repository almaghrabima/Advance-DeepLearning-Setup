#!/bin/bash
# Direct fix: Wrap the entire tmux block with a TTY check

echo "🔧 Applying direct fix to disable tmux for non-TTY connections..."

ssh -T vastai /bin/sh << 'FIX' 2>&1 | grep -E "(✅|Modified|Error|Failed)" || true
set -eu

# Backup
cp ~/.bashrc ~/.bashrc.backup.direct.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true

# Read .bashrc and wrap the tmux block
TMP=$(mktemp)
IN_TMUX_BLOCK=0
TMUX_BLOCK_START=0

while IFS= read -r line; do
    if [[ "$line" == *"# Auto-start tmux on SSH login"* ]]; then
        # Add TTY check before the tmux block
        echo "# Auto-start tmux on SSH login" >> "$TMP"
        echo "# Skip tmux for non-TTY connections (like Cursor remote SSH)" >> "$TMP"
        echo "if [ ! -t 0 ]; then" >> "$TMP"
        echo "    : # Do nothing for non-TTY" >> "$TMP"
        echo "elif command -v tmux &> /dev/null && [ -n \"\$PS1\" ] && [[ ! \"\$TERM\" =~ screen ]] && [[ ! \"\$TERM\" =~ tmux ]] && [ -z \"\$TMUX\" ] && [ -n \"\$SSH_CONNECTION\" ]; then" >> "$TMP"
        IN_TMUX_BLOCK=1
        TMUX_BLOCK_START=1
    elif [[ "$line" == "fi"* ]] && [ $IN_TMUX_BLOCK -eq 1 ] && [ $TMUX_BLOCK_START -eq 1 ]; then
        echo "$line" >> "$TMP"
        echo "fi  # End TTY check" >> "$TMP"
        IN_TMUX_BLOCK=0
    else
        echo "$line" >> "$TMP"
    fi
done < ~/.bashrc

mv "$TMP" ~/.bashrc
echo "✅ Modified .bashrc to wrap tmux block with TTY check"
FIX

echo ""
echo "✅ Fix applied! Try connecting with Cursor now."
