#!/usr/bin/env bash
# Create Vast.ai instance with 500GB container disk and 500GB volume mounted at /workspace

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <offer_id> [template_id]"
    echo ""
    echo "Example:"
    echo "  $0 28705860 329623"
    echo ""
    echo "To find an offer:"
    echo "  vastai search offers --limit 5"
    exit 1
fi

OFFER_ID="$1"
TEMPLATE_ID="${2:-329623}"  # Default to template 329623 if not provided

VASTAI_CMD="/opt/homebrew/bin/vastai"
VOLUME_SIZE=500
MOUNT_PATH="/workspace"

echo "🚀 Creating Vast.ai Instance with Volume"
echo "=========================================="
echo "Offer ID: $OFFER_ID"
echo "Template ID: $TEMPLATE_ID"
echo "Container Disk: 500 GB"
echo "Volume Size: ${VOLUME_SIZE} GB"
echo "Volume Mount Path: ${MOUNT_PATH}"
echo ""

# First, search for available volume offers
echo "🔍 Searching for volume offers (${VOLUME_SIZE}GB)..."
VOLUME_OFFERS=$($VASTAI_CMD search volumes --raw 2>&1 | python3 << PYTHON
import sys, json
try:
    data = json.load(sys.stdin)
    volumes = data.get('volumes', [])
    # Filter for volumes >= 500GB
    suitable = [v for v in volumes if v.get('size_gb', 0) >= ${VOLUME_SIZE}]
    if suitable:
        # Sort by price and get cheapest
        suitable.sort(key=lambda x: x.get('dph', 0))
        vol = suitable[0]
        print(vol.get('id'))
        print(f"Volume ID: {vol.get('id')}, Size: {vol.get('size_gb')}GB, Price: \${vol.get('dph', 0):.4f}/hr")
    else:
        print("NONE")
        print("No suitable volume offers found")
except Exception as e:
    print("ERROR")
    print(f"Error: {e}")
PYTHON
)

VOLUME_ID=$(echo "$VOLUME_OFFERS" | head -1)
VOLUME_INFO=$(echo "$VOLUME_OFFERS" | tail -n +2)

if [ "$VOLUME_ID" = "NONE" ] || [ "$VOLUME_ID" = "ERROR" ]; then
    echo "⚠️  $VOLUME_INFO"
    echo ""
    echo "Creating instance without volume (volume can be added later)..."
    echo ""
    
    # Create instance without volume
    echo "🚀 Creating instance..."
    CREATE_OUTPUT=$($VASTAI_CMD create instance "$OFFER_ID" \
        --image "almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai" \
        --template "$TEMPLATE_ID" \
        --disk 500 \
        --ssh \
        --direct 2>&1)
else
    echo "✅ Found volume: $VOLUME_INFO"
    echo ""
    
    # Create instance with volume
    echo "🚀 Creating instance with volume..."
    CREATE_OUTPUT=$($VASTAI_CMD create instance "$OFFER_ID" \
        --image "almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai" \
        --template "$TEMPLATE_ID" \
        --disk 500 \
        --create-volume "$VOLUME_ID" \
        --volume-size "$VOLUME_SIZE" \
        --mount-path "$MOUNT_PATH" \
        --ssh \
        --direct 2>&1)
fi

if [ $? -eq 0 ]; then
    echo "$CREATE_OUTPUT"
    echo ""
    
    # Extract instance ID
    INSTANCE_ID=$(echo "$CREATE_OUTPUT" | python3 -c "import sys, re; match = re.search(r\"'new_contract':\s*(\d+)\", sys.stdin.read()); print(match.group(1) if match else '')" 2>/dev/null || \
                  echo "$CREATE_OUTPUT" | grep -oE '[0-9]+' | head -1)
    
    if [ -n "$INSTANCE_ID" ]; then
        echo "✅ Instance created successfully!"
        echo "   Instance ID: $INSTANCE_ID"
        echo ""
        echo "⏳ Waiting 30 seconds for instance to initialize..."
        sleep 30
        echo ""
        echo "📊 Instance details:"
        $VASTAI_CMD show instance "$INSTANCE_ID" 2>&1 | head -5
        echo ""
        echo "🔐 SSH connection:"
        $VASTAI_CMD ssh-url "$INSTANCE_ID" 2>&1
        echo ""
        echo "📝 To verify volume mount:"
        echo "   ssh root@<host> -p <port>"
        echo "   df -h | grep workspace"
        echo "   ls -la /workspace/"
    else
        echo "✅ Instance created! (ID extraction failed, check output above)"
    fi
else
    echo "❌ Error creating instance:"
    echo "$CREATE_OUTPUT"
    exit 1
fi
