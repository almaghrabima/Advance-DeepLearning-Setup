#!/usr/bin/env bash
# Create Vast.ai instance with fast internet using CLI, use template 329609, and verify smctm

set -euo pipefail

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

VASTAI_CMD="/opt/homebrew/bin/vastai"
TEMPLATE_ID=329609

echo "🚀 Creating Vast.ai Instance with Fast Internet"
echo "================================================"
echo "Template ID: $TEMPLATE_ID"
echo ""

# Check if vastai CLI is available
if [ ! -f "$VASTAI_CMD" ]; then
    echo "❌ Error: vastai CLI not found at $VASTAI_CMD"
    echo "   Install with: pip install vastai"
    exit 1
fi

# Step 1: Search for offers with fast internet
echo "🔍 Searching for offers with fast internet..."
echo "   (Sorting by network speed - Net_down column)"
echo ""

# Get offers and parse the table output to find one with good network speed
echo "Fetching offers..."
OFFERS_OUTPUT=$($VASTAI_CMD search offers --limit 20 2>&1)

if [ $? -ne 0 ] || [ -z "$OFFERS_OUTPUT" ]; then
    echo "❌ Error searching offers"
    echo "$OFFERS_OUTPUT"
    exit 1
fi

# Parse the table output (skip header, get first few offers, sort by Net_down)
OFFER_ID=$(echo "$OFFERS_OUTPUT" | python3 << 'PYTHON'
import sys
import re

lines = sys.stdin.readlines()
if not lines:
    sys.exit(1)

# Find the header line
header_idx = -1
for i, line in enumerate(lines):
    if 'Net_down' in line or 'Net' in line:
        header_idx = i
        break

if header_idx == -1:
    # No header found, try to parse anyway
    header_idx = 0

# Parse offers (skip header)
offers = []
for line in lines[header_idx + 1:]:
    if not line.strip() or line.strip().startswith('-'):
        continue
    # Parse tab-separated or space-separated values
    parts = line.split()
    if len(parts) >= 2:
        try:
            offer_id = int(parts[0])
            # Try to find Net_down value (usually around column 12-13)
            net_down = 0
            if len(parts) > 12:
                try:
                    net_down = float(parts[12])
                except:
                    pass
            offers.append((offer_id, net_down, line.strip()))
        except:
            continue

# Sort by network speed (Net_down) descending
offers.sort(key=lambda x: x[1], reverse=True)

if not offers:
    sys.exit(1)

# Display top 5
print("Top 5 offers by network speed:")
for i, (oid, net_down, line) in enumerate(offers[:5], 1):
    print(f"{i}. {line[:80]}...")

# Select the best one
selected_id = offers[0][0]
selected_net = offers[0][1]
print(f"\n✅ Selected offer ID: {selected_id} (Net_down: {selected_net:.1f} Mbps)")
print(selected_id)
PYTHON
)

if [ -z "$OFFER_ID" ]; then
    echo "❌ Could not find suitable offer"
    exit 1
fi
echo ""

# Step 2: Create instance using template
echo "🚀 Creating instance with template $TEMPLATE_ID..."
CREATE_OUTPUT=$($VASTAI_CMD create instance $OFFER_ID \
    --image almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai \
    --template $TEMPLATE_ID \
    --ssh 2>&1)

if [ $? -ne 0 ]; then
    echo "❌ Error creating instance:"
    echo "$CREATE_OUTPUT"
    exit 1
fi

echo "$CREATE_OUTPUT"
echo ""

# Extract instance ID from output
INSTANCE_ID=$(echo "$CREATE_OUTPUT" | grep -oE '[0-9]+' | head -1)

if [ -z "$INSTANCE_ID" ]; then
    echo "⚠️  Could not extract instance ID from output"
    echo "   Please check manually: $VASTAI_CMD show instances"
    exit 1
fi

echo "✅ Instance created! ID: $INSTANCE_ID"
echo ""
echo "⏳ Waiting 45 seconds for instance to initialize and container to start..."
sleep 45

# Step 3: Get instance details and check for smctm
echo ""
echo "📊 Getting instance details..."
INSTANCE_INFO=$($VASTAI_CMD show instance $INSTANCE_ID 2>&1)

if [ $? -ne 0 ]; then
    echo "⚠️  Could not get instance info:"
    echo "$INSTANCE_INFO"
    echo ""
    echo "Please check manually: $VASTAI_CMD show instance $INSTANCE_ID"
    exit 1
fi

echo "$INSTANCE_INFO"
echo ""

# Get SSH URL
SSH_URL=$($VASTAI_CMD ssh-url $INSTANCE_ID 2>&1)

if [ -z "$SSH_URL" ] || [[ "$SSH_URL" == *"Error"* ]] || [[ "$SSH_URL" == *"not available"* ]]; then
    echo "⚠️  SSH not available yet. Instance may still be starting."
    echo "   Check status: $VASTAI_CMD show instance $INSTANCE_ID"
    echo "   Try again in a few minutes"
    exit 0
fi

echo "🔐 SSH Connection: $SSH_URL"
echo ""

# Extract host and port from SSH URL
# SSH URL format: ssh://root@host:port or root@host -p port
SSH_HOST=$(echo "$SSH_URL" | sed -E 's|.*@([^:/]+).*|\1|')
SSH_PORT=$(echo "$SSH_URL" | sed -E 's|.*:([0-9]+).*|\1|' || echo "22")

echo "🔍 Checking for /workspace/smctm..."
echo "   (This may take a moment as the container initializes)"
echo ""

# Wait a bit more for container to fully start
sleep 10

# Try to check for smctm via SSH
SSH_CMD="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=15 -o UserKnownHostsFile=/dev/null root@${SSH_HOST} -p ${SSH_PORT}"

# Check if smctm exists
echo "Checking /workspace/smctm..."
SMCTM_CHECK=$($SSH_CMD 'ls -la /workspace/smctm 2>&1' 2>/dev/null)

if echo "$SMCTM_CHECK" | grep -q "No such file\|cannot access\|not found"; then
    echo "⚠️  /workspace/smctm NOT FOUND yet"
    echo ""
    echo "The container may still be initializing. The entrypoint should clone it automatically."
    echo ""
    echo "To check manually:"
    echo "  $SSH_CMD"
    echo "  ls -la /workspace/"
    echo "  ls -la /workspace/smctm/"
    echo ""
    echo "Or check the container logs to see if the entrypoint is running:"
    echo "  $SSH_CMD 'docker ps && docker logs <container_id>'"
else
    echo "✅ /workspace/smctm EXISTS!"
    echo ""
    echo "Details:"
    $SSH_CMD 'cd /workspace/smctm && pwd && echo "" && git status 2>&1 | head -10' 2>/dev/null || echo "Could not get git status"
    echo ""
    echo "✅ smctm repository is successfully cloned!"
fi

echo ""
echo "📝 Instance Details:"
echo "   Instance ID: $INSTANCE_ID"
echo "   SSH: $SSH_URL"
echo "   Check status: $VASTAI_CMD show instance $INSTANCE_ID"
echo "   View in browser: https://console.vast.ai/instances"
