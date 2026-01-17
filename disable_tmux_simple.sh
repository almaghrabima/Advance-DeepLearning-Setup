#!/bin/bash
# Simple script to disable tmux by commenting out the exec line

echo "Disabling tmux in .bashrc..."

ssh vastai bash << 'DISABLE' 2>/dev/null
# Comment out the exec tmux line
sed -i 's/^[[:space:]]*exec tmux attach-session -t main$/# &/' ~/.bashrc

# Verify the change
if grep -q "^#.*exec tmux" ~/.bashrc; then
    echo "SUCCESS: tmux exec line commented out"
else
    echo "Checking alternative patterns..."
    # Try without leading spaces
    sed -i 's/exec tmux attach-session -t main/# &/' ~/.bashrc
    if grep -q "#.*exec tmux" ~/.bashrc; then
        echo "SUCCESS: tmux exec line commented out (alternative method)"
    else
        echo "WARNING: Could not find or comment tmux line"
        echo "Current .bashrc tmux section:"
        grep -A 3 "Auto-start tmux" ~/.bashrc || echo "Could not find tmux section"
    fi
fi
DISABLE

echo "Done. Try connecting with Cursor now."
