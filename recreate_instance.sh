#!/usr/bin/env bash
# Recreate Vast.ai instance if current one is stuck

set -euo pipefail

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

INSTANCE_ID=30109581
VASTAI_CMD="/opt/homebrew/bin/vastai"
IMAGE="almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai"

# Build ENV_VARS from environment variables
if [ -z "${GIT_USER_EMAIL:-}" ] || [ -z "${WANDB_API_KEY:-}" ] || [ -z "${PROJECT_REPO:-}" ] || [ -z "${GITHUB_PAT:-}" ] || [ -z "${HUGGING_FACE_HUB_TOKEN:-}" ] || [ -z "${GIT_USER_NAME:-}" ]; then
    echo "❌ Error: Required environment variables not found"
    echo "   Please create a .env file with the following variables:"
    echo "   - GIT_USER_EMAIL"
    echo "   - WANDB_API_KEY"
    echo "   - PROJECT_REPO"
    echo "   - GITHUB_PAT"
    echo "   - HUGGING_FACE_HUB_TOKEN"
    echo "   - GIT_USER_NAME"
    echo ""
    echo "   See .env.example for reference"
    exit 1
fi

ENV_VARS="GIT_USER_EMAIL=${GIT_USER_EMAIL} WANDB_API_KEY=${WANDB_API_KEY} PROJECT_REPO=${PROJECT_REPO} HF_HUB_ENABLE_HF_TRANSFER=1 GITHUB_PAT=${GITHUB_PAT} HUGGING_FACE_HUB_TOKEN=${HUGGING_FACE_HUB_TOKEN} GIT_USER_NAME=${GIT_USER_NAME}"

echo "🔄 Recreating Vast.ai Instance"
echo "==============================="
echo ""

# Check current status
echo "📊 Current instance status:"
$VASTAI_CMD show instance $INSTANCE_ID 2>&1 | head -3
echo ""

read -p "⚠️  This will destroy instance $INSTANCE_ID. Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cancelled"
    exit 1
fi

# Destroy current instance
echo "🗑️  Destroying instance $INSTANCE_ID..."
$VASTAI_CMD destroy instance $INSTANCE_ID 2>&1
echo ""

# Wait a moment
sleep 5

# Search for a new offer
echo "🔍 Searching for available offers..."
OFFERS=$($VASTAI_CMD search offers --limit 5 2>&1)
echo "$OFFERS" | head -10
echo ""

# Get first offer ID
OFFER_ID=$(echo "$OFFERS" | grep -E "^[0-9]+" | head -1 | awk '{print $1}')
if [ -z "$OFFER_ID" ]; then
    echo "❌ Could not find suitable offer"
    exit 1
fi

echo "✅ Selected offer: $OFFER_ID"
echo ""

# Create new instance
echo "🚀 Creating new instance..."
$VASTAI_CMD create instance $OFFER_ID \
    --image "$IMAGE" \
    --env "$ENV_VARS" \
    --ssh 2>&1

NEW_INSTANCE_ID=$(echo "$OUTPUT" | grep -oP "new_contract['\"]?\s*:\s*\K[0-9]+" || echo "")

if [ -n "$NEW_INSTANCE_ID" ]; then
    echo ""
    echo "✅ New instance created: $NEW_INSTANCE_ID"
    echo ""
    echo "📝 Check status:"
    echo "   $VASTAI_CMD show instance $NEW_INSTANCE_ID"
    echo ""
    echo "🔐 Get SSH URL:"
    echo "   $VASTAI_CMD ssh-url $NEW_INSTANCE_ID"
else
    echo ""
    echo "⚠️  Instance creation response received. Check manually:"
    echo "   $VASTAI_CMD show instances"
fi
