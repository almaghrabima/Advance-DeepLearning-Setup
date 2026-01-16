#!/usr/bin/env bash
# Create Vast.ai instance with GITHUB_REPO env var to clone smctm

set -euo pipefail

if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

VASTAI_CMD="/opt/homebrew/bin/vastai"
OFFER_ID="${1:-26158836}"  # Use provided offer ID or default

echo "🚀 Creating Vast.ai Instance"
echo "Offer ID: $OFFER_ID"
echo "Image: almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai"
echo ""

# Build env string
ENV_STRING="GITHUB_REPO=https://github.com/almaghrabima/smctm.git"
ENV_STRING="${ENV_STRING} PROJECT_REPO=https://github.com/almaghrabima/smctm.git"
ENV_STRING="${ENV_STRING} GIT_USER_EMAIL=${GIT_USER_EMAIL}"
ENV_STRING="${ENV_STRING} GIT_USER_NAME=${GIT_USER_NAME}"
ENV_STRING="${ENV_STRING} GITHUB_PAT=${GITHUB_PAT}"
ENV_STRING="${ENV_STRING} WANDB_API_KEY=${WANDB_API_KEY}"
ENV_STRING="${ENV_STRING} HF_HUB_ENABLE_HF_TRANSFER=1"
ENV_STRING="${ENV_STRING} HUGGING_FACE_HUB_TOKEN=${HUGGING_FACE_HUB_TOKEN}"

echo "Creating instance with environment variables..."
$VASTAI_CMD create instance "$OFFER_ID" \
    --image almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai \
    --env "$ENV_STRING" \
    --ssh

echo ""
echo "⏳ Waiting 60 seconds for instance to start and container to initialize..."
sleep 60

echo ""
echo "📊 Instance status:"
$VASTAI_CMD show instances

echo ""
echo "✅ Instance created! To check for smctm:"
echo "   1. Get instance ID from above"
echo "   2. Get SSH URL: $VASTAI_CMD ssh-url <instance_id>"
echo "   3. SSH in and check: ls -la /workspace/smctm/"
