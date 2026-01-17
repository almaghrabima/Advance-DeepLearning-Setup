#!/usr/bin/env bash
# Destroy and recreate a Vast.ai instance to fix port conflicts or other issues

set -euo pipefail

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

VASTAI_CMD="/opt/homebrew/bin/vastai"

# Parse arguments
SKIP_CONFIRM=false
INSTANCE_ID=""
TEMPLATE_ID=""

# Parse flags and arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --yes|-y)
            SKIP_CONFIRM=true
            shift
            ;;
        *)
            if [ -z "$INSTANCE_ID" ]; then
                INSTANCE_ID="$1"
            elif [ -z "$TEMPLATE_ID" ]; then
                TEMPLATE_ID="$1"
            fi
            shift
            ;;
    esac
done

# Set defaults
INSTANCE_ID="${INSTANCE_ID:-30136512}"
DEFAULT_TEMPLATE_ID="${TEMPLATE_ID:-329609}"
IMAGE="almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai"

# Check if API token is available
if [ -z "${VAST_API_TOKEN:-}" ]; then
    echo "❌ Error: VAST_API_TOKEN not found in environment variables"
    echo "   Please create a .env file with VAST_API_TOKEN (see .env.example)"
    exit 1
fi

echo "🔄 Destroy and Recreate Vast.ai Instance"
echo "========================================="
echo "Instance ID to destroy: $INSTANCE_ID"
echo "Default Template ID: $DEFAULT_TEMPLATE_ID"
echo "Image: $IMAGE"
echo ""

# Step 1: Try to get template ID from existing instance
echo "📊 Step 1: Checking existing instance..."
INSTANCE_INFO=$($VASTAI_CMD show instance $INSTANCE_ID 2>&1 || echo "ERROR")

if echo "$INSTANCE_INFO" | grep -q "ERROR\|not found\|does not exist"; then
    echo "⚠️  Instance $INSTANCE_ID not found or already destroyed"
    echo "   Will use default template ID: $DEFAULT_TEMPLATE_ID"
    TEMPLATE_ID="$DEFAULT_TEMPLATE_ID"
else
    echo "✅ Found instance. Attempting to extract template ID..."
    
    # Try to extract template ID from instance info
    TEMPLATE_ID=$(echo "$INSTANCE_INFO" | python3 << 'PYTHON'
import sys
import re
import json

content = sys.stdin.read()

# Try to find template_id in the output
patterns = [
    r'template[_\s]*id["\s:]+(\d+)',
    r'"template_id":\s*(\d+)',
    r'template_id["\s:]+(\d+)',
]

for pattern in patterns:
    match = re.search(pattern, content, re.IGNORECASE)
    if match:
        print(match.group(1))
        sys.exit(0)

# If not found, return empty
print("")
PYTHON
    )
    
    if [ -z "$TEMPLATE_ID" ]; then
        echo "⚠️  Could not extract template ID from instance"
        echo "   Will use default template ID: $DEFAULT_TEMPLATE_ID"
        TEMPLATE_ID="$DEFAULT_TEMPLATE_ID"
    else
        echo "✅ Found template ID: $TEMPLATE_ID"
    fi
fi

echo ""
echo "📋 Configuration:"
echo "   Template ID: $TEMPLATE_ID"
echo "   Image: $IMAGE"
echo ""

# Step 2: Confirm destruction
if [ "$SKIP_CONFIRM" = false ]; then
    read -p "⚠️  This will DESTROY instance $INSTANCE_ID and create a new one. Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Cancelled"
        exit 1
    fi
else
    echo "⚠️  Proceeding with destruction (--yes flag provided)"
fi

# Step 3: Destroy the instance
echo ""
echo "🗑️  Step 2: Destroying instance $INSTANCE_ID..."
DESTROY_OUTPUT=$($VASTAI_CMD destroy instance $INSTANCE_ID 2>&1 || echo "ERROR")

if echo "$DESTROY_OUTPUT" | grep -q "ERROR\|error\|failed"; then
    echo "⚠️  Warning: Destroy command may have failed:"
    echo "$DESTROY_OUTPUT"
    echo ""
    echo "   The instance may already be destroyed or not exist."
    echo "   Continuing with recreation..."
else
    echo "✅ Instance destroyed (or already destroyed)"
fi

# Step 4: Wait for cleanup
echo ""
echo "⏳ Step 3: Waiting 10 seconds for cleanup..."
sleep 10

# Step 5: Search for available offers
echo ""
echo "🔍 Step 4: Searching for available GPU offers..."
OFFER_OUTPUT=$($VASTAI_CMD search offers --limit 5 2>&1)

if [ -z "$OFFER_OUTPUT" ]; then
    echo "❌ No offers found"
    exit 1
fi

# Extract first offer ID
OFFER_LINE=$(echo "$OFFER_OUTPUT" | grep -E "^[0-9]" | head -1)

if [ -z "$OFFER_LINE" ]; then
    echo "❌ Could not find offer data"
    echo "Output: $OFFER_OUTPUT"
    exit 1
fi

OFFER_ID=$(echo "$OFFER_LINE" | awk '{print $1}')

if [ -z "$OFFER_ID" ] || ! [[ "$OFFER_ID" =~ ^[0-9]+$ ]]; then
    echo "❌ Could not extract offer ID"
    echo "Offer line: $OFFER_LINE"
    exit 1
fi

echo "✅ Selected offer ID: $OFFER_ID"
echo ""

# Display offer details
echo "📋 Offer Details:"
echo "$OFFER_OUTPUT" | head -3
echo ""

# Step 6: Create new instance
echo "🚀 Step 5: Creating new instance..."
echo "   Using template: $TEMPLATE_ID"
echo "   On offer: $OFFER_ID"
echo ""

# Try with template first, fallback to image-only if template fails
if [ -n "$TEMPLATE_ID" ] && [ "$TEMPLATE_ID" != "NONE" ]; then
    CREATE_OUTPUT=$($VASTAI_CMD create instance $OFFER_ID \
        --image "$IMAGE" \
        --template $TEMPLATE_ID \
        --ssh 2>&1)
    
    # If template fails, try without template
    if echo "$CREATE_OUTPUT" | grep -q "invalid template\|template not accessible\|template not found"; then
        echo "⚠️  Template $TEMPLATE_ID not accessible, trying without template..."
        CREATE_OUTPUT=$($VASTAI_CMD create instance $OFFER_ID \
            --image "$IMAGE" \
            --ssh 2>&1)
    fi
else
    # Create without template
    CREATE_OUTPUT=$($VASTAI_CMD create instance $OFFER_ID \
        --image "$IMAGE" \
        --ssh 2>&1)
fi

echo "$CREATE_OUTPUT"
echo ""

# Step 7: Extract and display new instance ID
NEW_INSTANCE_ID=$(echo "$CREATE_OUTPUT" | python3 << 'PYTHON'
import sys
import re

content = sys.stdin.read()

# Try multiple patterns to find instance ID
patterns = [
    r"'new_contract':\s*(\d+)",
    r'"new_contract":\s*(\d+)',
    r"new_contract['\"]?\s*:\s*(\d+)",
    r'new_contract["\s:]+(\d+)',
    r'instance[_\s]*id["\s:]+(\d+)',
    r'"id":\s*(\d+)',
    r'contract["\s:]+(\d+)',
    r'new_contract.*?(\d{8,})',  # Match 8+ digit numbers after new_contract
]

for pattern in patterns:
    match = re.search(pattern, content, re.IGNORECASE)
    if match:
        print(match.group(1))
        sys.exit(0)

# If no pattern matches, try to find any large number that might be an ID
numbers = re.findall(r'\b\d{6,}\b', content)
if numbers:
    print(numbers[0])
    sys.exit(0)

print("")
PYTHON
)

if [ -n "$NEW_INSTANCE_ID" ]; then
    echo "✅ New instance created successfully!"
    echo "   New Instance ID: $NEW_INSTANCE_ID"
    echo ""
    
    echo "⏳ Waiting 30 seconds for instance to initialize..."
    sleep 30
    echo ""
    
    echo "📊 Step 6: Getting instance details..."
    $VASTAI_CMD show instance $NEW_INSTANCE_ID 2>&1 | head -10
    echo ""
    
    echo "🔐 SSH Connection:"
    SSH_URL=$($VASTAI_CMD ssh-url $NEW_INSTANCE_ID 2>&1 || echo "")
    if [ -n "$SSH_URL" ]; then
        echo "   $SSH_URL"
        echo ""
        echo "   To connect:"
        if echo "$SSH_URL" | grep -q "ssh://"; then
            HOST_PORT=$(echo "$SSH_URL" | sed 's|ssh://root@||' | sed 's|ssh://||' | sed 's|/||')
            echo "   ssh root@$(echo $HOST_PORT | cut -d: -f1) -p $(echo $HOST_PORT | cut -d: -f2)"
        else
            echo "   $SSH_URL"
        fi
    else
        echo "   SSH URL not available yet. Instance may still be starting."
        echo "   Check again in a minute: $VASTAI_CMD ssh-url $NEW_INSTANCE_ID"
    fi
    echo ""
    
    echo "✅ Done! Your new instance is being set up."
    echo ""
    echo "📝 Next steps:"
    echo "   1. Wait for instance to fully start (may take 2-5 minutes)"
    echo "   2. Check status: $VASTAI_CMD show instance $NEW_INSTANCE_ID"
    echo "   3. Get SSH URL: $VASTAI_CMD ssh-url $NEW_INSTANCE_ID"
    echo "   4. Connect and verify: ssh root@<host> -p <port>"
    echo "   5. Check workspace: ls -la /workspace/"
else
    echo "⚠️  Could not extract new instance ID from output"
    echo ""
    echo "📝 Please check manually:"
    echo "   $VASTAI_CMD show instances"
    echo ""
    echo "   Or check the vast.ai console:"
    echo "   https://console.vast.ai/instances"
fi
