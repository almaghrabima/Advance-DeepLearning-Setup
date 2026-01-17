#!/usr/bin/env bash
# Create Vast.ai instance with fast internet, use template 329609, and verify smctm

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
    echo "   Please create a .env file with VAST_API_TOKEN"
    exit 1
fi

TEMPLATE_ID=329609
IMAGE="almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai"

echo "🚀 Creating Vast.ai Instance with Fast Internet"
echo "================================================"
echo "Template ID: $TEMPLATE_ID"
echo "Image: $IMAGE"
echo ""

# Step 1: Search for available offers with good internet speed
# Filter for on-demand offers and sort by network speed/bandwidth
echo "🔍 Searching for offers with fast internet..."
OFFERS_RESPONSE=$(curl -s -X GET "https://cloud.vast.ai/api/v0/offers/" \
    -H "Authorization: Bearer $API_TOKEN" \
    -G -d "q=on-demand" \
    -d "type=ask")

# Parse and find offers with best internet (prioritize by bandwidth or network speed)
echo "$OFFERS_RESPONSE" | python3 << 'PYTHON'
import sys, json
try:
    data = json.load(sys.stdin)
    offers = data.get('offers', [])
    on_demand = [o for o in offers if o.get('on_demand', False)]
    
    if not on_demand:
        print("❌ No on-demand offers found")
        sys.exit(1)
    
    # Sort by bandwidth (higher is better) or network speed
    # Some offers have 'inet_up' and 'inet_down' fields for network speed
    def get_network_score(offer):
        # Try to get network bandwidth/speed metrics
        inet_up = float(offer.get('inet_up', 0) or 0)
        inet_down = float(offer.get('inet_down', 0) or 0)
        bandwidth = float(offer.get('bandwidth', 0) or 0)
        # Return combined score (upload + download for total throughput)
        # If bandwidth is available, use it; otherwise sum upload and download
        if bandwidth > 0:
            return bandwidth
        return inet_up + inet_down
    
    # Sort by network score (descending)
    on_demand.sort(key=get_network_score, reverse=True)
    
    # Show top 5 offers
    print(f"✅ Found {len(on_demand)} on-demand offers (sorted by network speed):\n")
    for i, offer in enumerate(on_demand[:5], 1):
        network_score = get_network_score(offer)
        inet_up = float(offer.get('inet_up', 0) or 0)
        inet_down = float(offer.get('inet_down', 0) or 0)
        print(f"{i}. Offer ID: {offer.get('id')}")
        print(f"   GPU: {offer.get('gpu_name', 'N/A')}")
        print(f"   Price: ${offer.get('dph_total', 0):.2f}/hr")
        print(f"   RAM: {offer.get('ram', 0)/1024:.1f}GB")
        print(f"   Disk: {offer.get('disk_space', 0):.1f}GB")
        if inet_up > 0 or inet_down > 0:
            print(f"   Network: ↑{inet_up:.1f} Mbps / ↓{inet_down:.1f} Mbps (Total: {network_score:.1f} Mbps)")
        elif network_score > 0:
            print(f"   Network: {network_score:.1f} Mbps")
        print("")
    
    # Select the best one (highest network score)
    selected = on_demand[0]
    with open('/tmp/vastai_offer_id.txt', 'w') as f:
        f.write(str(selected.get('id')))
    print(f"📝 Selected offer ID: {selected.get('id')} (best network speed)")
except Exception as e:
    print(f"❌ Error parsing offers: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYTHON

if [ ! -f /tmp/vastai_offer_id.txt ]; then
    echo "❌ Could not find suitable offer"
    exit 1
fi

OFFER_ID=$(cat /tmp/vastai_offer_id.txt)
echo ""
echo "🚀 Creating instance on offer $OFFER_ID with template $TEMPLATE_ID..."

# Step 2: Create instance using template
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
    sys.exit(1)
PYTHON

if [ ! -f /tmp/vastai_instance_id.txt ]; then
    echo "❌ Instance creation failed"
    exit 1
fi

INSTANCE_ID=$(cat /tmp/vastai_instance_id.txt)
echo ""
echo "⏳ Waiting 30 seconds for instance to initialize and container to start..."
sleep 30

# Step 3: Get instance details and check for smctm
echo ""
echo "📊 Getting instance details and checking for smctm..."
INSTANCE_RESPONSE=$(curl -s -X GET "https://cloud.vast.ai/api/v0/asks/" \
    -H "Authorization: Bearer $API_TOKEN")

echo "$INSTANCE_RESPONSE" | python3 << PYTHON
import sys, json
import subprocess
import time

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
        
        # Try to check for smctm via SSH
        print(f"\n🔍 Checking for /workspace/smctm...")
        print("   (This may take a moment as the container initializes)")
        
        # Wait a bit more for container to fully start
        time.sleep(10)
        
        # Try SSH command to check for smctm
        ssh_cmd = f"ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -p {ssh_port} root@{ssh_host} 'ls -la /workspace/smctm 2>/dev/null && echo SMCTM_EXISTS || echo SMCTM_NOT_FOUND'"
        
        try:
            result = subprocess.run(ssh_cmd, shell=True, capture_output=True, text=True, timeout=30)
            if "SMCTM_EXISTS" in result.stdout:
                print("   ✅ /workspace/smctm EXISTS!")
                # Get more details
                detail_cmd = f"ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -p {ssh_port} root@{ssh_host} 'cd /workspace/smctm && pwd && git status 2>&1 | head -5'"
                detail_result = subprocess.run(detail_cmd, shell=True, capture_output=True, text=True, timeout=30)
                print(f"   Details:")
                print(f"   {detail_result.stdout}")
            elif "SMCTM_NOT_FOUND" in result.stdout:
                print("   ⚠️  /workspace/smctm NOT FOUND yet")
                print("   The container may still be initializing. Try again in a minute:")
                print(f"   ssh root@{ssh_host} -p {ssh_port}")
                print(f"   ls -la /workspace/")
            else:
                print(f"   ⚠️  Could not connect via SSH yet (instance may still be starting)")
                print(f"   SSH manually: ssh root@{ssh_host} -p {ssh_port}")
        except subprocess.TimeoutExpired:
            print("   ⚠️  SSH connection timed out (instance may still be starting)")
        except Exception as e:
            print(f"   ⚠️  Could not check via SSH: {e}")
            print(f"   Please check manually: ssh root@{ssh_host} -p {ssh_port}")
    else:
        print(f"\n⚠️  SSH details not available yet (instance may still be starting)")
        print(f"   Check at: https://console.vast.ai/instances")
    
    jupyter_url = instance.get('jupyter_url') or instance.get('jupyter_link')
    if jupyter_url:
        print(f"\n📓 Jupyter:")
        print(f"   {jupyter_url}")
    
    print(f"\n📝 Manual verification steps:")
    print(f"   1. SSH: ssh root@{ssh_host if ssh_host else 'INSTANCE_IP'} -p {ssh_port if ssh_host else 22}")
    print(f"   2. Check: ls -la /workspace/smctm/")
    print(f"   3. Verify: cd /workspace/smctm && git status")
    
except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
PYTHON

echo ""
echo "✅ Done! Check your instance at: https://console.vast.ai/instances"
