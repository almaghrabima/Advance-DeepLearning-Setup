#!/usr/bin/env bash
# Update Vast.ai template 329625 with environment variables from .env

set -euo pipefail

# Load environment variables from .env file
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

VASTAI_CMD="/opt/homebrew/bin/vastai"
TEMPLATE_HASH="12e585cbfbe799ff31240c1e91daf787"  # Hash from template creation output
TEMPLATE_ID=329625

# Check if API token is provided
if [ -z "${VAST_API_TOKEN:-}" ]; then
    echo "❌ Error: VAST_API_TOKEN environment variable is not set"
    exit 1
fi

# Check required environment variables
REQUIRED_VARS=("WANDB_API_KEY" "GITHUB_PAT" "HUGGING_FACE_HUB_TOKEN" "GIT_USER_EMAIL" "GIT_USER_NAME" "PROJECT_REPO")
MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var:-}" ]; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -ne 0 ]; then
    echo "❌ Error: Missing required environment variables:"
    for var in "${MISSING_VARS[@]}"; do
        echo "   - $var"
    done
    exit 1
fi

# Use PROJECT_REPO as fallback for GITHUB_REPO if not set
if [ -z "${GITHUB_REPO:-}" ]; then
    echo "ℹ️  GITHUB_REPO not set, using PROJECT_REPO as fallback: ${PROJECT_REPO}"
    export GITHUB_REPO="${PROJECT_REPO}"
fi

echo "🔄 Updating Template $TEMPLATE_ID with Environment Variables"
echo "============================================================"
echo ""

# Build environment string with proper Docker format
# Port mappings: -p 8888:8888 -p 6006:6006 -p 22:22
# Environment variables: -e KEY=VALUE
ENV_STRING="-p 8888:8888 -p 6006:6006 -p 22:22 -e GIT_USER_EMAIL=${GIT_USER_EMAIL} -e WANDB_API_KEY=${WANDB_API_KEY} -e PROJECT_REPO=${PROJECT_REPO} -e GITHUB_REPO=${GITHUB_REPO} -e HF_HUB_ENABLE_HF_TRANSFER=1 -e GITHUB_PAT=${GITHUB_PAT} -e HUGGING_FACE_HUB_TOKEN=${HUGGING_FACE_HUB_TOKEN} -e GIT_USER_NAME=${GIT_USER_NAME}"

echo "📋 Environment Variables to Set:"
echo "   GIT_USER_EMAIL=${GIT_USER_EMAIL}"
echo "   WANDB_API_KEY=${WANDB_API_KEY:0:10}..."
echo "   PROJECT_REPO=${PROJECT_REPO}"
echo "   GITHUB_REPO=${GITHUB_REPO}"
echo "   HF_HUB_ENABLE_HF_TRANSFER=1"
echo "   GITHUB_PAT=${GITHUB_PAT:0:10}..."
echo "   HUGGING_FACE_HUB_TOKEN=${HUGGING_FACE_HUB_TOKEN:0:10}..."
echo "   GIT_USER_NAME=${GIT_USER_NAME}"
echo ""

# Update template using CLI
echo "🚀 Updating template..."
UPDATE_OUTPUT=$($VASTAI_CMD update template "$TEMPLATE_HASH" \
    --env "$ENV_STRING" 2>&1)

if [ $? -eq 0 ]; then
    echo "$UPDATE_OUTPUT"
    echo ""
    echo "✅ Template updated successfully!"
    echo "   Template ID: $TEMPLATE_ID"
    echo "   Template Hash: $TEMPLATE_HASH"
    echo ""
    echo "📝 Verify in Vast.ai UI: https://console.vast.ai/templates"
else
    echo "❌ Error updating template:"
    echo "$UPDATE_OUTPUT"
    exit 1
fi
