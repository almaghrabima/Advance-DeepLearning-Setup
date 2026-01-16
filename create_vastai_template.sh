#!/usr/bin/env bash
set -euo pipefail

# Script to create Vast.ai template via API
# Requires: Vast.ai API token and .env file with all required variables

VAST_API_URL="https://console.vast.ai/api/v0/template/"
TEMPLATE_JSON="vastai_template.json"

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

# Check if API token is provided
if [ -z "${VAST_API_TOKEN:-}" ]; then
    echo "❌ Error: VAST_API_TOKEN environment variable is not set"
    echo ""
    echo "Usage:"
    echo "  Create a .env file with VAST_API_TOKEN (see .env.example)"
    echo "  ./create_vastai_template.sh"
    echo ""
    echo "To get your API token:"
    echo "  1. Go to https://console.vast.ai/account"
    echo "  2. Navigate to API section"
    echo "  3. Copy your API token"
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
    echo "Please ensure all variables are set in your .env file (see .env.example)"
    exit 1
fi

# Use PROJECT_REPO as fallback for GITHUB_REPO if not set
# GITHUB_REPO is used by entrypoint.sh to clone the repository (e.g., smctm)
if [ -z "${GITHUB_REPO:-}" ]; then
    echo "ℹ️  GITHUB_REPO not set, using PROJECT_REPO as fallback: ${PROJECT_REPO}"
    export GITHUB_REPO="${PROJECT_REPO}"
fi

# Check if template JSON file exists
if [ ! -f "$TEMPLATE_JSON" ]; then
    echo "❌ Error: Template JSON file not found: $TEMPLATE_JSON"
    exit 1
fi

echo "📋 Reading template configuration from: $TEMPLATE_JSON"
echo "🔗 API Endpoint: $VAST_API_URL"
echo ""

# Build the env string from environment variables
# GITHUB_REPO is used by the entrypoint.sh to clone the repository (e.g., smctm)
ENV_STRING="GIT_USER_EMAIL=${GIT_USER_EMAIL} WANDB_API_KEY=${WANDB_API_KEY} PROJECT_REPO=${PROJECT_REPO} GITHUB_REPO=${GITHUB_REPO} HF_HUB_ENABLE_HF_TRANSFER=1 GITHUB_PAT=${GITHUB_PAT} HUGGING_FACE_HUB_TOKEN=${HUGGING_FACE_HUB_TOKEN} GIT_USER_NAME=${GIT_USER_NAME}"

# Create temporary JSON file with substituted values
TEMP_JSON=$(mktemp)
if command -v jq &> /dev/null; then
    jq --arg env "$ENV_STRING" '.env = $env' "$TEMPLATE_JSON" > "$TEMP_JSON"
else
    # Fallback if jq is not available - use Python
    python3 << EOF > "$TEMP_JSON"
import json
import sys

with open("$TEMPLATE_JSON", "r") as f:
    data = json.load(f)

data["env"] = "$ENV_STRING"
print(json.dumps(data, indent=2))
EOF
fi

# Create template via API
echo "🚀 Creating Vast.ai template..."
RESPONSE=$(curl -s -w "\n%{http_code}" \
    --request POST \
    --url "$VAST_API_URL" \
    --header "Authorization: Bearer $VAST_API_TOKEN" \
    --header "Content-Type: application/json" \
    --data @"$TEMP_JSON")

# Clean up temporary file
rm -f "$TEMP_JSON"

# Extract HTTP status code (last line)
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
# Extract response body (all but last line)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
    echo "✅ Template created successfully!"
    echo ""
    echo "Response:"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    echo ""
    
    # Try to extract template ID if response is JSON
    TEMPLATE_ID=$(echo "$BODY" | jq -r '.id // .template_id // empty' 2>/dev/null || echo "")
    if [ -n "$TEMPLATE_ID" ] && [ "$TEMPLATE_ID" != "null" ]; then
        echo "📝 Template ID: $TEMPLATE_ID"
        echo ""
        echo "✅ Template created with GitHub repository configuration:"
        echo "   - GITHUB_REPO: ${GITHUB_REPO}"
        echo "   - Docker Image: almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai"
        echo ""
        echo "Next steps:"
        echo "  1. Verify template in Vast.ai UI: https://console.vast.ai/templates"
        echo "  2. Launch an instance using this template"
        echo "  3. After instance starts, SSH in and verify smctm is cloned:"
        echo "     - ls -la /workspace/smctm/"
        echo "     - cd /workspace/smctm && git status"
    fi
else
    echo "❌ Error: Failed to create template (HTTP $HTTP_CODE)"
    echo ""
    echo "Response:"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    echo ""
    echo "Common issues:"
    echo "  - Invalid API token"
    echo "  - Template name already exists"
    echo "  - Invalid JSON format"
    echo "  - Missing required fields"
    exit 1
fi
