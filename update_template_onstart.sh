#!/usr/bin/env bash
# Update Vast.ai template with new onstart script that clones repository
# Automatically finds the template hash and updates it

set -euo pipefail

# Load environment variables from .env file
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

VASTAI_CMD="/opt/homebrew/bin/vastai"

# Accept template ID or hash as argument
if [ $# -ge 1 ]; then
    if [[ "$1" =~ ^[a-f0-9]{32}$ ]]; then
        # It's a hash
        TEMPLATE_HASH="$1"
        TEMPLATE_ID=""
        echo "ℹ️  Using template hash directly: $TEMPLATE_HASH"
    else
        # It's an ID
        TEMPLATE_ID="$1"
        TEMPLATE_HASH=""
    fi
else
    TEMPLATE_ID="${TEMPLATE_ID:-329625}"  # Default template ID
    TEMPLATE_HASH=""
fi

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

echo "🔄 Updating Template with New Onstart Script"
echo "=========================================================="
echo ""

# Find the current template hash if not provided
if [ -z "$TEMPLATE_HASH" ]; then
    if [ -z "$TEMPLATE_ID" ]; then
        echo "❌ Error: Need either template ID or hash"
        echo "   Usage: $0 <template_id> OR $0 <hash_id>"
        exit 1
    fi
    
    echo "🔍 Finding Template $TEMPLATE_ID..."
    TEMPLATE_SEARCH=$($VASTAI_CMD search templates --raw 2>&1)

    if echo "$TEMPLATE_SEARCH" | grep -q "id.*$TEMPLATE_ID"; then
    # Extract hash_id for the template
    TEMPLATE_HASH=$(echo "$TEMPLATE_SEARCH" | python3 << 'PYTHON'
import sys
import json
import re

try:
    # Try to parse as JSON first
    data = json.load(sys.stdin)
    templates = data if isinstance(data, list) else data.get('templates', [])
    
    template_id = sys.argv[1] if len(sys.argv) > 1 else "329625"
    
    for template in templates:
        if str(template.get('id')) == str(template_id):
            print(template.get('hash_id', ''))
            sys.exit(0)
except:
    # Fallback to regex parsing
    content = sys.stdin.read()
    template_id = sys.argv[1] if len(sys.argv) > 1 else "329625"
    
    # Look for pattern: "id": 329625 ... "hash_id": "abc123"
    pattern = rf'"id":\s*{template_id}.*?"hash_id":\s*"([^"]+)"'
    match = re.search(pattern, content, re.DOTALL)
    if match:
        print(match.group(1))
        sys.exit(0)
    
    # Alternative pattern
    pattern = rf'hash_id["\s:]+([a-f0-9]+).*?id["\s:]+{template_id}'
    match = re.search(pattern, content, re.DOTALL)
    if match:
        print(match.group(1))
        sys.exit(0)

sys.exit(1)
PYTHON
    "$TEMPLATE_ID" 2>/dev/null || echo "")
    
    if [ -z "$TEMPLATE_HASH" ]; then
        echo "⚠️  Could not extract hash from search, trying alternative method..."
        # Alternative: search for template by ID in raw output
        TEMPLATE_HASH=$(echo "$TEMPLATE_SEARCH" | grep -A 10 "id.*$TEMPLATE_ID" | grep -oP 'hash_id["\s:]+["\s]*([a-f0-9]+)' | head -1 | sed 's/.*\([a-f0-9]\{32\}\).*/\1/' || echo "")
    fi
    
    if [ -z "$TEMPLATE_HASH" ]; then
        echo "❌ Could not find template hash for template ID $TEMPLATE_ID"
        echo ""
        echo "💡 Options:"
        echo "   1. Find your template hash manually:"
        echo "      $VASTAI_CMD search templates --raw | grep -A 5 'id.*$TEMPLATE_ID'"
        echo ""
        echo "   2. Use template hash directly:"
        echo "      $0 <hash_id>"
        echo ""
        echo "   3. List all your templates:"
        echo "      $VASTAI_CMD search templates"
        exit 1
    fi
    
    echo "✅ Found template hash: $TEMPLATE_HASH"
else
    echo "❌ Template $TEMPLATE_ID not found in search results"
    echo ""
    echo "💡 Try:"
    echo "   1. List all templates: $VASTAI_CMD search templates"
    echo "   2. Use template hash directly: $0 <hash_id>"
    exit 1
fi
fi

# If we have a hash, proceed with update
if [ -n "$TEMPLATE_HASH" ]; then
    echo "✅ Using template hash: $TEMPLATE_HASH"
else
    echo "✅ Template hash provided: $TEMPLATE_HASH"
fi

# Build environment string with proper Docker format
ENV_STRING="-p 8888:8888 -p 6006:6006 -p 22:22 -e GIT_USER_EMAIL=${GIT_USER_EMAIL} -e WANDB_API_KEY=${WANDB_API_KEY} -e PROJECT_REPO=${PROJECT_REPO} -e GITHUB_REPO=${GITHUB_REPO} -e HF_HUB_ENABLE_HF_TRANSFER=1 -e GITHUB_PAT=${GITHUB_PAT} -e HUGGING_FACE_HUB_TOKEN=${HUGGING_FACE_HUB_TOKEN} -e GIT_USER_NAME=${GIT_USER_NAME}"

# Onstart command: Run onstart script to clone repository, then start-project.sh
# The onstart script will clone the repository and log to /var/log/onstart.log
ONSTART_CMD="bash -c '/usr/local/bin/onstart.sh 2>&1 | tee -a /var/log/onstart.log; if [ -f /usr/local/bin/start-project.sh ]; then /usr/local/bin/start-project.sh; else start-project.sh; fi'"

TEMPLATE_NAME="Advance DeepLearning Setup - 500GB (PyTorch 2.8 + CUDA 12.8)"

echo ""
echo "📋 Template Configuration:"
echo "   Name: $TEMPLATE_NAME"
if [ -n "$TEMPLATE_ID" ]; then
    echo "   Template ID: $TEMPLATE_ID"
fi
echo "   Template Hash: $TEMPLATE_HASH"
echo "   Docker Image: almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai"
echo "   Onstart: $ONSTART_CMD"
echo ""

# Update template using CLI
echo "🚀 Updating template with new onstart script..."
UPDATE_OUTPUT=$($VASTAI_CMD update template "$TEMPLATE_HASH" \
    --name "$TEMPLATE_NAME" \
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
    if [ -n "$TEMPLATE_ID" ]; then
        echo "   Template ID: $TEMPLATE_ID"
    fi
    if [ -n "$NEW_HASH" ]; then
        echo "   New Template Hash: $NEW_HASH"
        echo "   (Template hash changes on each update)"
    fi
    echo ""
    echo "📝 What was updated:"
    echo "   ✓ Onstart script now runs /usr/local/bin/onstart.sh"
    echo "   ✓ Repository will be cloned automatically on instance start"
    echo "   ✓ Logs available at /var/log/onstart.log"
    echo ""
    echo "🔗 Verify in Vast.ai UI: https://console.vast.ai/templates"
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
