#!/usr/bin/env bash
# Create Vast.ai template with 500GB container disk, port mappings, and environment variables from .env

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
    exit 1
fi

# Use PROJECT_REPO as fallback for GITHUB_REPO if not set
if [ -z "${GITHUB_REPO:-}" ]; then
    echo "ℹ️  GITHUB_REPO not set, using PROJECT_REPO as fallback: ${PROJECT_REPO}"
    export GITHUB_REPO="${PROJECT_REPO}"
fi

echo "🚀 Creating Vast.ai Template with Volume Configuration"
echo "======================================================"
echo "Container Disk: 500 GB"
echo "Volume Disk: 500 GB (configured at instance creation)"
echo "Volume Mount Path: /workspace"
echo "HTTP Ports: 8888, 6006"
echo "TCP Ports: 22"
echo ""

# Build environment string with port mappings
# Port mappings: -p 8888:8888 -p 6006:6006 -p 22:22
ENV_STRING="-p 8888:8888 -p 6006:6006 -p 22:22 GIT_USER_EMAIL=${GIT_USER_EMAIL} WANDB_API_KEY=${WANDB_API_KEY} PROJECT_REPO=${PROJECT_REPO} GITHUB_REPO=${GITHUB_REPO} HF_HUB_ENABLE_HF_TRANSFER=1 GITHUB_PAT=${GITHUB_PAT} HUGGING_FACE_HUB_TOKEN=${HUGGING_FACE_HUB_TOKEN} GIT_USER_NAME=${GIT_USER_NAME}"

echo "📋 Template Configuration:"
echo "   Name: advance-deeplearning-500gb-volume"
echo "   Image: almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai"
echo "   Disk Space: 500 GB"
echo "   Port Mappings: 8888, 6006 (HTTP), 22 (TCP)"
echo ""

# Create template using CLI
echo "🚀 Creating template..."
TEMPLATE_OUTPUT=$($VASTAI_CMD create template \
    --name "advance-deeplearning-500gb-volume" \
    --image "almamoha/advance-deeplearning" \
    --image_tag "torch2.8-cuda12.8-vastai" \
    --disk_space 500 \
    --ssh \
    --direct \
    --env "$ENV_STRING" \
    --search_params "external=false rentable=true verified=true" 2>&1)

if [ $? -eq 0 ]; then
    echo "$TEMPLATE_OUTPUT"
    echo ""
    
    # Extract template ID from output
    TEMPLATE_ID=$(echo "$TEMPLATE_OUTPUT" | python3 -c "import sys, re; match = re.search(r\"'id':\s*(\d+)\", sys.stdin.read()); print(match.group(1) if match else '')" 2>/dev/null || echo "")
    
    if [ -n "$TEMPLATE_ID" ]; then
        echo "✅ Template created successfully!"
        echo "   Template ID: $TEMPLATE_ID"
        echo ""
        echo "📝 Note: Volume configuration (500GB mounted at /workspace) will be set"
        echo "   when creating instances using this template."
        echo ""
        echo "To create an instance with volume:"
        echo "  ./create_instance_with_volume.sh <offer_id> $TEMPLATE_ID"
    else
        echo "✅ Template created! (ID extraction failed, check output above)"
    fi
else
    echo "❌ Error creating template:"
    echo "$TEMPLATE_OUTPUT"
    exit 1
fi
