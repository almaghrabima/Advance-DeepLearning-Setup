#!/usr/bin/env bash
# Update Vast.ai template 329625 with name and entrypoint configuration

set -euo pipefail

# Load environment variables from .env file
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

VASTAI_CMD="/opt/homebrew/bin/vastai"
TEMPLATE_HASH="438a8be6f16b3ec2501812dafc0e766f"  # Current hash - update this if template changes
TEMPLATE_ID=329625

# Docker Hub credentials
DOCKER_USERNAME="almamoha"
DOCKER_PAT="${DOCKER_PAT:-YOUR_DOCKER_PAT}"  # Load from .env file
# Note: Login string must be in single quotes to preserve spaces
DOCKER_LOGIN="-u ${DOCKER_USERNAME} -p ${DOCKER_PAT} docker.io"

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

echo "🔄 Updating Template $TEMPLATE_ID with Name and Entrypoint"
echo "=========================================================="
echo ""

# Build environment string with proper Docker format
# Port mappings: -p 8888:8888 -p 6006:6006 -p 22:22
# Environment variables: -e KEY=VALUE
ENV_STRING="-p 8888:8888 -p 6006:6006 -p 22:22 -e GIT_USER_EMAIL=${GIT_USER_EMAIL} -e WANDB_API_KEY=${WANDB_API_KEY} -e PROJECT_REPO=${PROJECT_REPO} -e GITHUB_REPO=${GITHUB_REPO} -e HF_HUB_ENABLE_HF_TRANSFER=1 -e GITHUB_PAT=${GITHUB_PAT} -e HUGGING_FACE_HUB_TOKEN=${HUGGING_FACE_HUB_TOKEN} -e GIT_USER_NAME=${GIT_USER_NAME}"

# Onstart command: Run onstart script to clone repository, then start-project.sh
# The onstart script will clone the repository and log to /var/log/onstart.log
ONSTART_CMD="bash -c '/usr/local/bin/onstart.sh 2>&1 | tee -a /var/log/onstart.log; if [ -f /usr/local/bin/start-project.sh ]; then /usr/local/bin/start-project.sh; else start-project.sh; fi'"

TEMPLATE_NAME="Advance DeepLearning Setup - 500GB (PyTorch 2.8 + CUDA 12.8)"

echo "📋 Template Configuration:"
echo "   Name: $TEMPLATE_NAME"
echo "   Template ID: $TEMPLATE_ID"
echo "   Docker Image: almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai"
echo "   Docker Auth: ${DOCKER_USERNAME}@docker.io"
echo "   Entrypoint: /usr/local/bin/entrypoint.sh"
echo "   CMD: bash -lc start-project.sh"
echo "   Onstart: $ONSTART_CMD"
echo ""

# Update template using CLI
# Note: --login must use single quotes to preserve the argument string
echo "🚀 Updating template with Docker authentication..."
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
    
    # Extract new hash from output
    NEW_HASH=$(echo "$UPDATE_OUTPUT" | python3 -c "import sys, re; match = re.search(r'\"hash_id\":\s*\"([^\"]+)\"', sys.stdin.read()); print(match.group(1) if match else '')" 2>/dev/null || echo "")
    
    echo "✅ Template updated successfully!"
    echo "   Template ID: $TEMPLATE_ID"
    if [ -n "$NEW_HASH" ]; then
        echo "   Template Hash: $NEW_HASH"
        echo "   (Update this hash in scripts for future updates)"
    fi
    echo ""
    echo "📝 Template Details:"
    echo "   - Name: $TEMPLATE_NAME"
    echo "   - Docker Image: almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai"
    echo "   - Docker Auth: ${DOCKER_USERNAME}@docker.io ✓"
    echo "   - Container Disk: 500 GB"
    echo "   - Volume Mount: /workspace (500GB configured at instance creation)"
    echo "   - Ports: 8888 (Jupyter), 6006 (TensorBoard), 22 (SSH)"
    echo "   - Entrypoint: /usr/local/bin/entrypoint.sh"
    echo "   - Start Script: start-project.sh"
    echo ""
    echo "🔗 Verify in Vast.ai UI: https://console.vast.ai/templates"
else
    echo "❌ Error updating template:"
    echo "$UPDATE_OUTPUT"
    exit 1
fi
