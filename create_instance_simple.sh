#!/usr/bin/env bash
# Simple script to create Vast.ai instance with template 329609 and check for smctm

set -euo pipefail

if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

VASTAI_CMD="/opt/homebrew/bin/vastai"
TEMPLATE_ID=329609

echo "🚀 Creating Vast.ai Instance"
echo "Template ID: $TEMPLATE_ID"
echo ""

# Get first available offer
echo "🔍 Getting first available offer..."
OFFER_OUTPUT=$($VASTAI_CMD search offers --limit 1 2>&1)

if [ -z "$OFFER_OUTPUT" ]; then
    echo "❌ No offers found"
    exit 1
fi

# Skip header lines and get the first data line
OFFER_LINE=$(echo "$OFFER_OUTPUT" | grep -E "^[0-9]" | head -1)

if [ -z "$OFFER_LINE" ]; then
    echo "❌ Could not find offer data line"
    echo "Output: $OFFER_OUTPUT"
    exit 1
fi

# Extract offer ID (first number in the line)
OFFER_ID=$(echo "$OFFER_LINE" | awk '{print $1}')

if [ -z "$OFFER_ID" ] || ! [[ "$OFFER_ID" =~ ^[0-9]+$ ]]; then
    echo "❌ Could not extract offer ID from: $OFFER_OUTPUT"
    exit 1
fi

echo "✅ Selected offer ID: $OFFER_ID"
echo ""

# Create instance
echo "🚀 Creating instance..."
$VASTAI_CMD create instance $OFFER_ID \
    --image almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai \
    --template $TEMPLATE_ID \
    --ssh

echo ""
echo "⏳ Waiting 60 seconds for instance to start..."
sleep 60

echo ""
echo "📊 Getting instance info..."
$VASTAI_CMD show instances

echo ""
echo "🔍 To check for smctm, get SSH URL and connect:"
echo "  $VASTAI_CMD ssh-url <instance_id>"
echo "  ssh root@<host> -p <port>"
echo "  ls -la /workspace/smctm/"
