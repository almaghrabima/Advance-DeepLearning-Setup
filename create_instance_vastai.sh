#!/usr/bin/env bash
# Create Vast.ai instance using CLI-style API calls
# Based on: https://docs.vast.ai/cli/commands

set -euo pipefail

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

API_TOKEN="${VAST_API_TOKEN:-}"
if [ -z "$API_TOKEN" ]; then
    echo "❌ Error: VAST_API_TOKEN not found in environment variables"
    echo "   Please create a .env file with VAST_API_TOKEN (see .env.example)"
    exit 1
fi
TEMPLATE_ID=329499
IMAGE="almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai"

echo "🚀 Creating Vast.ai Instance"
echo "=============================="
echo "Template ID: $TEMPLATE_ID"
echo "Image: $IMAGE"
echo ""

# Step 1: Search for available offers
echo "🔍 Searching for available GPU offers..."
OFFERS_RESPONSE=$(curl -s -X GET "https://cloud.vast.ai/api/v0/offers/" \
    -H "Authorization: Bearer $API_TOKEN" \
    -G -d "q=on-demand" \
    -d "type=ask")

# Parse and display offers
echo "$OFFERS_RESPONSE" | python3 << 'PYTHON'
import sys, json
try:
    data = json.load(sys.stdin)
    offers = data.get('offers', [])
    on_demand = [o for o in offers if o.get('on_demand', False)][:5]
    
    if not on_demand:
        print("❌ No on-demand offers found")
        sys.exit(1)
    
    print(f"✅ Found {len(on_demand)} on-demand offers:\n")
    for i, offer in enumerate(on_demand, 1):
        print(f"{i}. Offer ID: {offer.get('id')}")
        print(f"   GPU: {offer.get('gpu_name', 'N/A')}")
        print(f"   Price: ${offer.get('dph_total', 0):.2f}/hr")
        print(f"   RAM: {offer.get('ram', 0)/1024:.1f}GB")
        print(f"   Disk: {offer.get('disk_space', 0):.1f}GB")
        print("")
    
    # Save first offer ID to file for next step
    with open('/tmp/vastai_offer_id.txt', 'w') as f:
        f.write(str(on_demand[0].get('id')))
    print(f"📝 Selected offer ID: {on_demand[0].get('id')}")
except Exception as e:
    print(f"❌ Error parsing offers: {e}")
    sys.exit(1)
PYTHON

if [ ! -f /tmp/vastai_offer_id.txt ]; then
    echo "❌ Could not find suitable offer"
    exit 1
fi

OFFER_ID=$(cat /tmp/vastai_offer_id.txt)
echo ""
echo "🚀 Creating instance on offer $OFFER_ID..."

# Step 2: Create instance using template
# Based on CLI: vastai create instance <offer_id> --image <image> --template <template_id>
CREATE_RESPONSE=$(curl -s -X PUT "https://cloud.vast.ai/api/v0/asks/$OFFER_ID" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"client_id\": \"me\",
        \"template_id\": $TEMPLATE_ID,
        \"image\": \"$IMAGE\"
    }")

# Check if creation was successful
echo "$CREATE_RESPONSE" | python3 << 'PYTHON'
import sys, json
try:
    data = json.load(sys.stdin)
    if data.get('success') or 'id' in data or 'new_contract' in data:
        instance_id = data.get('new_contract') or data.get('id') or data.get('job_id')
        print(f"✅ Instance created successfully!")
        print(f"   Instance ID: {instance_id}")
        print(f"\n📋 Response:")
        print(json.dumps(data, indent=2))
        
        # Save instance ID
        with open('/tmp/vastai_instance_id.txt', 'w') as f:
            f.write(str(instance_id))
    else:
        print("❌ Failed to create instance")
        print(json.dumps(data, indent=2))
        sys.exit(1)
except json.JSONDecodeError:
    print("❌ Invalid JSON response:")
    print(sys.stdin.read()[:500])
    sys.exit(1)
except Exception as e:
    print(f"❌ Error: {e}")
    print("Response:", sys.stdin.read()[:500])
    sys.exit(1)
PYTHON

if [ ! -f /tmp/vastai_instance_id.txt ]; then
    echo "❌ Instance creation failed"
    exit 1
fi

INSTANCE_ID=$(cat /tmp/vastai_instance_id.txt)
echo ""
echo "⏳ Waiting 15 seconds for instance to initialize..."
sleep 15

# Step 3: Get instance details and SSH info
echo ""
echo "📊 Getting instance details..."
INSTANCE_RESPONSE=$(curl -s -X GET "https://cloud.vast.ai/api/v0/asks/" \
    -H "Authorization: Bearer $API_TOKEN")

echo "$INSTANCE_RESPONSE" | python3 << PYTHON
import sys, json
try:
    data = json.load(sys.stdin)
    asks = data.get('asks', [])
    
    # Find our instance
    instance = None
    for ask in asks:
        if str(ask.get('id')) == '$INSTANCE_ID' or str(ask.get('job_id')) == '$INSTANCE_ID':
            instance = ask
            break
    
    if not instance:
        print("⚠️  Instance not found in list yet (may still be starting)")
        print("   Check manually at: https://console.vast.ai/instances")
        sys.exit(0)
    
    print("✅ Instance Details:")
    print(f"   ID: {instance.get('id')}")
    print(f"   Status: {instance.get('state', 'unknown')}")
    print(f"   Image: {instance.get('image', 'N/A')}")
    
    ssh_host = instance.get('ssh_host') or instance.get('public_ipaddr')
    ssh_port = instance.get('ssh_port', 22)
    
    if ssh_host:
        print(f"\n🔐 SSH Connection:")
        print(f"   ssh root@{ssh_host} -p {ssh_port}")
    else:
        print(f"\n⚠️  SSH details not available yet (instance may still be starting)")
    
    jupyter_url = instance.get('jupyter_url') or instance.get('jupyter_link')
    if jupyter_url:
        print(f"\n📓 Jupyter:")
        print(f"   {jupyter_url}")
    
    print(f"\n📝 To check for smctm project:")
    if ssh_host:
        print(f"   ssh root@{ssh_host} -p {ssh_port}")
        print(f"   cd /workspace")
        print(f"   ls -la smctm/")
        print(f"   env | grep PROJECT_REPO")
    else:
        print(f"   Wait for instance to fully start, then SSH in")
        print(f"   Check at: https://console.vast.ai/instances")
except Exception as e:
    print(f"❌ Error: {e}")
PYTHON

echo ""
echo "✅ Done! Check your instance at: https://console.vast.ai/instances"
