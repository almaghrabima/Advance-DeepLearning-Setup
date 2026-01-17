#!/usr/bin/env bash
# Create a new template based on an existing one, but with updated onstart command

set -euo pipefail

# Load environment variables from .env file
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

VASTAI_CMD="/opt/homebrew/bin/vastai"
SOURCE_HASH="${1:-af40316bac3ce07de566513af8903607}"

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
    export GITHUB_REPO="${PROJECT_REPO}"
fi

echo "📋 Creating New Template from Existing"
echo "======================================"
echo "Source Template Hash: $SOURCE_HASH"
echo ""

# Get template details
echo "🔍 Fetching source template details..."
TEMPLATE_JSON=$($VASTAI_CMD search templates --raw 2>&1 | python3 << 'PYTHON'
import sys
import json

try:
    data = json.load(sys.stdin)
    templates = data if isinstance(data, list) else []
    
    source_hash = sys.argv[1] if len(sys.argv) > 1 else ""
    
    for template in templates:
        if template.get('hash_id') == source_hash:
            print(json.dumps(template))
            sys.exit(0)
    
    print("NOT_FOUND")
except Exception as e:
    print(f"ERROR:{e}")

PYTHON
"$SOURCE_HASH" 2>/dev/null || echo "ERROR")

if [ "$TEMPLATE_JSON" = "NOT_FOUND" ] || [[ "$TEMPLATE_JSON" == ERROR* ]]; then
    echo "⚠️  Could not fetch template details automatically"
    echo "   Will use default values based on your .env file"
    echo ""
    
    # Use defaults
    TEMPLATE_NAME="Advance DeepLearning Setup - 500GB (PyTorch 2.8 + CUDA 12.8)"
    DOCKER_IMAGE="almamoha/advance-deeplearning"
    DOCKER_TAG="torch2.8-cuda12.8-vastai"
    DISK_SPACE=500
else
    # Parse template details
    TEMPLATE_NAME=$(echo "$TEMPLATE_JSON" | python3 -c "import sys, json; t=json.load(sys.stdin); print(t.get('name', 'Advance DeepLearning Setup - 500GB (PyTorch 2.8 + CUDA 12.8)'))")
    DOCKER_IMAGE=$(echo "$TEMPLATE_JSON" | python3 -c "import sys, json; t=json.load(sys.stdin); img=t.get('image', 'almamoha/advance-deeplearning'); print(img.split(':')[0] if ':' in img else img)")
    DOCKER_TAG=$(echo "$TEMPLATE_JSON" | python3 -c "import sys, json; t=json.load(sys.stdin); img=t.get('image', 'almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai'); print(img.split(':')[1] if ':' in img else 'torch2.8-cuda12.8-vastai')")
    DISK_SPACE=$(echo "$TEMPLATE_JSON" | python3 -c "import sys, json; t=json.load(sys.stdin); print(t.get('disk_space', 500))")
    
    echo "✅ Found template: $TEMPLATE_NAME"
    echo "   Image: $DOCKER_IMAGE:$DOCKER_TAG"
    echo "   Disk: ${DISK_SPACE}GB"
fi

# Build environment string
ENV_STRING="-p 8888:8888 -p 6006:6006 -p 22:22 -e GIT_USER_EMAIL=${GIT_USER_EMAIL} -e WANDB_API_KEY=${WANDB_API_KEY} -e PROJECT_REPO=${PROJECT_REPO} -e GITHUB_REPO=${GITHUB_REPO} -e HF_HUB_ENABLE_HF_TRANSFER=1 -e GITHUB_PAT=${GITHUB_PAT} -e HUGGING_FACE_HUB_TOKEN=${HUGGING_FACE_HUB_TOKEN} -e GIT_USER_NAME=${GIT_USER_NAME}"

# New onstart command with repository cloning
ONSTART_CMD="bash -c '/usr/local/bin/onstart.sh 2>&1 | tee -a /var/log/onstart.log; if [ -f /usr/local/bin/start-project.sh ]; then /usr/local/bin/start-project.sh; else start-project.sh; fi'"

# Add timestamp to template name to make it unique
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
NEW_TEMPLATE_NAME="${TEMPLATE_NAME} (Updated ${TIMESTAMP})"

echo ""
echo "📋 New Template Configuration:"
echo "   Name: $NEW_TEMPLATE_NAME"
echo "   Image: $DOCKER_IMAGE:$DOCKER_TAG"
echo "   Disk Space: ${DISK_SPACE}GB"
echo "   Onstart: $ONSTART_CMD"
echo ""

# Create new template
echo "🚀 Creating new template..."
CREATE_OUTPUT=$($VASTAI_CMD create template \
    --name "$NEW_TEMPLATE_NAME" \
    --image "$DOCKER_IMAGE" \
    --image_tag "$DOCKER_TAG" \
    --disk_space "$DISK_SPACE" \
    --ssh \
    --direct \
    --env "$ENV_STRING" \
    --onstart-cmd "$ONSTART_CMD" 2>&1)

if [ $? -eq 0 ]; then
    echo "$CREATE_OUTPUT"
    echo ""
    
    # Extract template ID and hash from output
    NEW_TEMPLATE_ID=$(echo "$CREATE_OUTPUT" | python3 -c "import sys, re; match = re.search(r\"'id':\s*(\d+)\", sys.stdin.read()); print(match.group(1) if match else '')" 2>/dev/null || echo "")
    NEW_TEMPLATE_HASH=$(echo "$CREATE_OUTPUT" | python3 -c "import sys, re; match = re.search(r'\"hash_id\":\s*\"([^\"]+)\"', sys.stdin.read()); print(match.group(1) if match else '')" 2>/dev/null || echo "")
    
    echo "✅ New template created successfully!"
    echo ""
    echo "📝 Template Details:"
    if [ -n "$NEW_TEMPLATE_ID" ]; then
        echo "   Template ID: $NEW_TEMPLATE_ID"
    fi
    if [ -n "$NEW_TEMPLATE_HASH" ]; then
        echo "   Template Hash: $NEW_TEMPLATE_HASH"
    fi
    echo "   Name: $NEW_TEMPLATE_NAME"
    echo "   Image: $DOCKER_IMAGE:$DOCKER_TAG"
    echo "   Disk Space: ${DISK_SPACE}GB"
    echo ""
    echo "✨ What's different:"
    echo "   ✓ Onstart script now runs /usr/local/bin/onstart.sh"
    echo "   ✓ Repository will be cloned automatically on instance start"
    echo "   ✓ Logs available at /var/log/onstart.log"
    echo ""
    echo "🔗 View in Vast.ai UI: https://console.vast.ai/templates"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Use this new template to create instances"
    echo "   2. Check /var/log/onstart.log after instance starts"
    echo "   3. Verify /workspace/smctm/ exists"
else
    echo "❌ Error creating template:"
    echo "$CREATE_OUTPUT"
    exit 1
fi
