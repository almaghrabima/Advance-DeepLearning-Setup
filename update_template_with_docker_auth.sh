#!/usr/bin/env bash
# Update Vast.ai template 329625 with Docker authentication
# Automatically finds the current template hash

set -euo pipefail

# Load environment variables from .env file
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

VASTAI_CMD="/opt/homebrew/bin/vastai"
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

echo "🔍 Finding Template $TEMPLATE_ID..."
echo "====================================="
echo ""

# Find template hash by searching templates
TEMPLATE_HASH=$($VASTAI_CMD search templates --raw 2>&1 | python3 << PYTHON
import sys, json, re
try:
    # Read the JSON data
    data = sys.stdin.read()
    # Use regex to find the template with id 329625 and extract hash_id
    # Look for pattern: "id": 329625 ... "hash_id": "xxxxx"
    pattern = r'"id":\s*329625.*?"hash_id":\s*"([^"]+)"'
    match = re.search(pattern, data, re.DOTALL)
    if match:
        print(match.group(1))
    else:
        # Try alternative: search backwards from id
        lines = data.split('\n')
        for i, line in enumerate(lines):
            if '"id": 329625' in line or '"id":329625' in line:
                # Look ahead for hash_id
                for j in range(i, min(i+20, len(lines))):
                    if '"hash_id"' in lines[j]:
                        hash_match = re.search(r'"hash_id":\s*"([^"]+)"', lines[j])
                        if hash_match:
                            print(hash_match.group(1))
                            sys.exit(0)
        print("NOT_FOUND")
except Exception as e:
    print(f"ERROR: {e}")
PYTHON
)

if [ -z "$TEMPLATE_HASH" ] || [ "$TEMPLATE_HASH" = "NOT_FOUND" ] || [[ "$TEMPLATE_HASH" == ERROR* ]]; then
    echo "❌ Could not find template hash for template ID $TEMPLATE_ID"
    echo "   Please check the template exists and try manually updating via UI"
    echo "   Or provide the template hash manually"
    exit 1
fi

echo "✅ Found template hash: $TEMPLATE_HASH"
echo ""

# Build environment string
ENV_STRING="-p 8888:8888 -p 6006:6006 -p 22:22 -e GIT_USER_EMAIL=${GIT_USER_EMAIL} -e WANDB_API_KEY=${WANDB_API_KEY} -e PROJECT_REPO=${PROJECT_REPO} -e GITHUB_REPO=${GITHUB_REPO} -e HF_HUB_ENABLE_HF_TRANSFER=1 -e GITHUB_PAT=${GITHUB_PAT} -e HUGGING_FACE_HUB_TOKEN=${HUGGING_FACE_HUB_TOKEN} -e GIT_USER_NAME=${GIT_USER_NAME}"

ONSTART_CMD="bash -lc 'if [ -f /usr/local/bin/start-project.sh ]; then /usr/local/bin/start-project.sh; else start-project.sh; fi'"

TEMPLATE_NAME="Advance DeepLearning Setup - 500GB (PyTorch 2.8 + CUDA 12.8)"

echo "🔄 Updating Template with Docker Authentication"
echo "================================================"
echo "   Template ID: $TEMPLATE_ID"
echo "   Template Hash: $TEMPLATE_HASH"
echo "   Docker Image: almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai"
echo "   Docker Auth: almamoha@docker.io"
echo ""

# Update template with Docker login
echo "🚀 Updating template..."
UPDATE_OUTPUT=$($VASTAI_CMD update template "$TEMPLATE_HASH" \
    --name "$TEMPLATE_NAME" \
    --login "-u almamoha -p \${DOCKER_PAT} docker.io" \
    --env "$ENV_STRING" \
    --onstart-cmd "$ONSTART_CMD" \
    --ssh \
    --direct \
    --disk_space 500 2>&1)

if [ $? -eq 0 ]; then
    echo "$UPDATE_OUTPUT"
    echo ""
    
    # Extract new hash
    NEW_HASH=$(echo "$UPDATE_OUTPUT" | python3 -c "import sys, re; match = re.search(r'\"hash_id\":\s*\"([^\"]+)\"', sys.stdin.read()); print(match.group(1) if match else '')" 2>/dev/null || echo "")
    
    echo "✅ Template updated successfully!"
    echo "   Template ID: $TEMPLATE_ID"
    if [ -n "$NEW_HASH" ]; then
        echo "   New Template Hash: $NEW_HASH"
    fi
    echo ""
    echo "📝 Docker Authentication: ✓ Configured"
    echo "   Username: almamoha"
    echo "   Registry: docker.io"
    echo ""
    echo "🔗 Verify in Vast.ai UI: https://console.vast.ai/templates"
else
    echo "❌ Error updating template:"
    echo "$UPDATE_OUTPUT"
    exit 1
fi
