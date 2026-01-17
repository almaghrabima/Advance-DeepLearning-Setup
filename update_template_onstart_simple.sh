#!/usr/bin/env bash
# Simple script to update Vast.ai template with new onstart script
# Usage: ./update_template_onstart_simple.sh <template_hash>
#   OR: ./update_template_onstart_simple.sh <template_id> (will try to find hash)

set -euo pipefail

# Load environment variables from .env file
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

VASTAI_CMD="/opt/homebrew/bin/vastai"

# Check if API token is provided
if [ -z "${VAST_API_TOKEN:-}" ]; then
    echo "❌ Error: VAST_API_TOKEN environment variable is not set"
    exit 1
fi

# Get template hash or ID from argument
if [ $# -lt 1 ]; then
    echo "Usage: $0 <template_hash> OR <template_id>"
    echo ""
    echo "To find your template hash:"
    echo "  $VASTAI_CMD search templates --raw | grep -A 10 'id.*YOUR_TEMPLATE_ID'"
    exit 1
fi

INPUT="$1"

# Check if input is a hash (32 hex characters) or ID
if [[ "$INPUT" =~ ^[a-f0-9]{32}$ ]]; then
    TEMPLATE_HASH="$INPUT"
    echo "✅ Using template hash: $TEMPLATE_HASH"
else
    TEMPLATE_ID="$INPUT"
    echo "🔍 Finding hash for template ID: $TEMPLATE_ID"
    
    # Try to find the hash
    TEMPLATE_JSON=$($VASTAI_CMD search templates --raw 2>&1)
    TEMPLATE_HASH=$(echo "$TEMPLATE_JSON" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    templates = data if isinstance(data, list) else []
    for t in templates:
        if str(t.get('id')) == '$TEMPLATE_ID':
            print(t.get('hash_id', ''))
            sys.exit(0)
except:
    pass
" 2>/dev/null || echo "")
    
    if [ -z "$TEMPLATE_HASH" ]; then
        echo "❌ Could not find template hash for ID $TEMPLATE_ID"
        echo "   Please provide the hash directly: $0 <hash_id>"
        exit 1
    fi
    
    echo "✅ Found template hash: $TEMPLATE_HASH"
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
    export GITHUB_REPO="${PROJECT_REPO}"
fi

# Build environment string
ENV_STRING="-p 8888:8888 -p 6006:6006 -p 22:22 -e GIT_USER_EMAIL=${GIT_USER_EMAIL} -e WANDB_API_KEY=${WANDB_API_KEY} -e PROJECT_REPO=${PROJECT_REPO} -e GITHUB_REPO=${GITHUB_REPO} -e HF_HUB_ENABLE_HF_TRANSFER=1 -e GITHUB_PAT=${GITHUB_PAT} -e HUGGING_FACE_HUB_TOKEN=${HUGGING_FACE_HUB_TOKEN} -e GIT_USER_NAME=${GIT_USER_NAME}"

# Onstart command: Run onstart script to clone repository, then start-project.sh
ONSTART_CMD="bash -c '/usr/local/bin/onstart.sh 2>&1 | tee -a /var/log/onstart.log; if [ -f /usr/local/bin/start-project.sh ]; then /usr/local/bin/start-project.sh; else start-project.sh; fi'"

TEMPLATE_NAME="Advance DeepLearning Setup - 500GB (PyTorch 2.8 + CUDA 12.8)"

echo ""
echo "📋 Updating Template:"
echo "   Hash: $TEMPLATE_HASH"
echo "   Name: $TEMPLATE_NAME"
echo "   Image: almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai"
echo ""

# Update template
echo "🚀 Updating template..."
UPDATE_OUTPUT=$($VASTAI_CMD update template "$TEMPLATE_HASH" \
    --name "$TEMPLATE_NAME" \
    --env "$ENV_STRING" \
    --onstart-cmd "$ONSTART_CMD" \
    --ssh \
    --direct \
    --disk_space 500 2>&1)

if [ $? -eq 0 ]; then
    echo "✅ Template updated successfully!"
    echo ""
    echo "📝 What was updated:"
    echo "   ✓ Onstart script now runs /usr/local/bin/onstart.sh"
    echo "   ✓ Repository will be cloned automatically on instance start"
    echo "   ✓ Logs available at /var/log/onstart.log"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Create a new instance using this template"
    echo "   2. Check /var/log/onstart.log after instance starts"
    echo "   3. Verify /workspace/smctm/ exists"
else
    echo "❌ Error updating template:"
    echo "$UPDATE_OUTPUT"
    exit 1
fi
