#!/usr/bin/env bash
# Create a complete Vast.ai template with all configurations
# Includes: 500GB disk, port mappings, environment variables, entrypoint, and Docker auth option

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
    echo "   Please create a .env file with VAST_API_TOKEN"
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
    echo ""
    echo "Please ensure all variables are set in your .env file"
    exit 1
fi

# Use PROJECT_REPO as fallback for GITHUB_REPO if not set
if [ -z "${GITHUB_REPO:-}" ]; then
    echo "ℹ️  GITHUB_REPO not set, using PROJECT_REPO as fallback: ${PROJECT_REPO}"
    export GITHUB_REPO="${PROJECT_REPO}"
fi

echo "🚀 Creating Vast.ai Template"
echo "============================="
echo ""

# Template configuration
TEMPLATE_NAME="Advance DeepLearning Setup - 500GB (PyTorch 2.8 + CUDA 12.8)"
DOCKER_IMAGE="almamoha/advance-deeplearning"
DOCKER_TAG="torch2.8-cuda12.8-vastai"
DISK_SPACE=500

# Build environment string with port mappings and environment variables
# Port mappings: -p 8888:8888 -p 6006:6006 -p 22:22
# Environment variables: -e KEY=VALUE
ENV_STRING="-p 8888:8888 -p 6006:6006 -p 22:22 -e GIT_USER_EMAIL=${GIT_USER_EMAIL} -e WANDB_API_KEY=${WANDB_API_KEY} -e PROJECT_REPO=${PROJECT_REPO} -e GITHUB_REPO=${GITHUB_REPO} -e HF_HUB_ENABLE_HF_TRANSFER=1 -e GITHUB_PAT=${GITHUB_PAT} -e HUGGING_FACE_HUB_TOKEN=${HUGGING_FACE_HUB_TOKEN} -e GIT_USER_NAME=${GIT_USER_NAME}"

# Onstart command to ensure start-project.sh runs
ONSTART_CMD="bash -lc 'if [ -f /usr/local/bin/start-project.sh ]; then /usr/local/bin/start-project.sh; else start-project.sh; fi'"

# Docker login credentials (optional - user can add manually via UI)
DOCKER_USERNAME="almamoha"
DOCKER_PAT="${DOCKER_PAT:-YOUR_DOCKER_PAT}"  # Load from .env file
DOCKER_LOGIN="-u ${DOCKER_USERNAME} -p ${DOCKER_PAT} docker.io"

echo "📋 Template Configuration:"
echo "   Name: $TEMPLATE_NAME"
echo "   Image: ${DOCKER_IMAGE}:${DOCKER_TAG}"
echo "   Container Disk: ${DISK_SPACE} GB"
echo "   Volume Mount: /workspace (500GB configured at instance creation)"
echo "   Ports: 8888 (Jupyter), 6006 (TensorBoard), 22 (SSH)"
echo "   Entrypoint: /usr/local/bin/entrypoint.sh"
echo "   Start Script: start-project.sh"
echo ""

# Docker authentication - user will add manually via UI
echo "🔐 Docker Repository Authentication:"
echo "   Username: $DOCKER_USERNAME"
echo "   Registry: docker.io"
echo "   ⚠️  Will be added manually via Vast.ai UI"
echo ""
INCLUDE_AUTH="n"

echo ""
echo "🚀 Creating template..."

# Build the command
CREATE_CMD="$VASTAI_CMD create template \
    --name \"$TEMPLATE_NAME\" \
    --image \"$DOCKER_IMAGE\" \
    --image_tag \"$DOCKER_TAG\" \
    --disk_space $DISK_SPACE \
    --ssh \
    --direct \
    --env \"$ENV_STRING\" \
    --onstart-cmd \"$ONSTART_CMD\" \
    --search_params \"external=false rentable=true verified=true\""

# Add Docker login if requested
if [[ "$INCLUDE_AUTH" =~ ^[Yy]$ ]]; then
    echo "   ✓ Including Docker authentication"
    CREATE_CMD="$CREATE_CMD --login '$DOCKER_LOGIN'"
else
    echo "   ⚠️  Docker authentication not included (add manually via UI)"
fi

# Execute the command
TEMPLATE_OUTPUT=$(eval $CREATE_CMD 2>&1)

if [ $? -eq 0 ]; then
    echo "$TEMPLATE_OUTPUT"
    echo ""
    
    # Extract template ID from output
    TEMPLATE_ID=$(echo "$TEMPLATE_OUTPUT" | python3 -c "import sys, re; match = re.search(r\"'id':\s*(\d+)\", sys.stdin.read()); print(match.group(1) if match else '')" 2>/dev/null || echo "")
    
    if [ -n "$TEMPLATE_ID" ]; then
        echo "✅ Template created successfully!"
        echo ""
        echo "📝 Template Details:"
        echo "   Template ID: $TEMPLATE_ID"
        echo "   Name: $TEMPLATE_NAME"
        echo "   Image: ${DOCKER_IMAGE}:${DOCKER_TAG}"
        echo "   Container Disk: ${DISK_SPACE} GB"
        echo "   Ports: 8888, 6006, 22"
        echo ""
        
        if [[ ! "$INCLUDE_AUTH" =~ ^[Yy]$ ]]; then
            echo "⚠️  Next Steps:"
            echo "   1. Go to https://console.vast.ai/templates"
            echo "   2. Find template ID: $TEMPLATE_ID"
            echo "   3. Add Docker Repository Authentication:"
            echo "      - Username: $DOCKER_USERNAME"
            echo "      - Password: \${DOCKER_PAT} (from .env file)"
            echo "      - Registry: docker.io"
            echo ""
        fi
        
        echo "🔗 View template: https://console.vast.ai/templates"
        echo ""
        echo "📦 To create an instance with volume:"
        echo "   ./create_instance_with_volume.sh <offer_id> $TEMPLATE_ID"
    else
        echo "✅ Template created! (ID extraction failed, check output above)"
    fi
else
    echo "❌ Error creating template:"
    echo "$TEMPLATE_OUTPUT"
    exit 1
fi
