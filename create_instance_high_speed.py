#!/usr/bin/env python3
"""Create Vast.ai instance with high-speed network and check for smctm"""
import json
import os
import sys
import time
import subprocess
from pathlib import Path

try:
    import requests
except ImportError:
    print("❌ Error: requests library not installed")
    print("   Install with: pip install requests")
    sys.exit(1)

# Load environment variables from .env file
try:
    from dotenv import load_dotenv
    env_path = Path(__file__).parent / '.env'
    load_dotenv(env_path)
except ImportError:
    # Fallback: manually load .env file
    env_path = Path(__file__).parent / '.env'
    if env_path.exists():
        with open(env_path, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    os.environ[key.strip()] = value.strip().strip('"').strip("'")

API_TOKEN = os.getenv("VAST_API_TOKEN")
if not API_TOKEN:
    print("❌ Error: VAST_API_TOKEN not found in environment variables")
    print("   Please create a .env file with VAST_API_TOKEN")
    sys.exit(1)

API_BASE = "https://cloud.vast.ai/api/v0"
HEADERS = {
    "Authorization": f"Bearer {API_TOKEN}",
    "Content-Type": "application/json"
}

TEMPLATE_ID = 329609
IMAGE = "almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai"

def get_network_score(offer):
    """Calculate network score for an offer (higher is better)"""
    inet_up = float(offer.get('inet_up', 0) or 0)
    inet_down = float(offer.get('inet_down', 0) or 0)
    bandwidth = float(offer.get('bandwidth', 0) or 0)
    # Return combined score (upload + download for total throughput)
    if bandwidth > 0:
        return bandwidth
    return inet_up + inet_down

def search_offers_high_speed():
    """Search for available on-demand offers and sort by network speed"""
    print("🔍 Searching for offers with fast internet...")
    print("   (Prioritizing high upload/download speeds)")
    print()
    
    try:
        response = requests.get(
            f"{API_BASE}/offers/",
            headers=HEADERS,
            params={"q": "on-demand", "type": "ask"},
            timeout=30
        )
        
        if response.status_code != 200:
            print(f"❌ Error searching offers: HTTP {response.status_code}")
            print(f"   Response: {response.text[:500]}")
            return None
        
        data = response.json()
        offers = data.get("offers", [])
        on_demand = [o for o in offers if o.get("on_demand", False)]
        
        if not on_demand:
            print("❌ No on-demand offers found")
            return None
        
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
            print()
        
        # Select the best one (highest network score)
        selected = on_demand[0]
        print(f"📝 Selected offer ID: {selected.get('id')} (best network speed)")
        return selected.get('id')
        
    except requests.exceptions.RequestException as e:
        print(f"❌ Error connecting to API: {e}")
        return None
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return None

def create_instance(offer_id, template_id):
    """Create an instance from template"""
    print(f"\n🚀 Creating instance on offer {offer_id} with template {template_id}...")
    
    payload = {
        "client_id": "me",
        "template_id": template_id,
        "image": IMAGE
    }
    
    try:
        response = requests.put(
            f"{API_BASE}/asks/{offer_id}",
            headers=HEADERS,
            json=payload,
            timeout=30
        )
        
        if response.status_code in [200, 201]:
            data = response.json()
            instance_id = data.get("new_contract") or data.get("id") or data.get("job_id")
            print(f"✅ Instance created successfully!")
            print(f"   Instance ID: {instance_id}")
            return instance_id
        else:
            print(f"❌ Error creating instance: HTTP {response.status_code}")
            print(f"   Response: {response.text[:500]}")
            return None
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Error connecting to API: {e}")
        return None
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return None

def get_instance_details(instance_id):
    """Get instance details and connection info"""
    print(f"\n📊 Getting instance details...")
    
    try:
        response = requests.get(f"{API_BASE}/asks/", headers=HEADERS, timeout=30)
        
        if response.status_code != 200:
            print(f"❌ Error getting instances: HTTP {response.status_code}")
            return None
        
        data = response.json()
        instances = data.get("asks", [])
        
        # Find our instance
        instance = None
        for inst in instances:
            if (str(inst.get("id")) == str(instance_id) or 
                str(inst.get("job_id")) == str(instance_id) or
                str(inst.get("new_contract")) == str(instance_id)):
                instance = inst
                break
        
        if not instance:
            print(f"⚠️  Instance {instance_id} not found in list yet (may still be starting)")
            print(f"   Check manually at: https://console.vast.ai/instances")
            return None
        
        print(f"✅ Instance Details:")
        print(f"   ID: {instance.get('id')}")
        print(f"   Status: {instance.get('state', 'unknown')}")
        print(f"   Image: {instance.get('image', 'N/A')}")
        
        ssh_host = instance.get('ssh_host') or instance.get('public_ipaddr')
        ssh_port = instance.get('ssh_port', 22)
        
        if ssh_host:
            print(f"\n🔐 SSH Connection:")
            print(f"   ssh root@{ssh_host} -p {ssh_port}")
            return {"host": ssh_host, "port": ssh_port, "instance": instance}
        else:
            print(f"\n⚠️  SSH details not available yet (instance may still be starting)")
            return None
            
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return None

def check_smctm(ssh_host, ssh_port):
    """Check if smctm directory exists in the VM"""
    print(f"\n🔍 Checking for /workspace/smctm...")
    print(f"   (This may take a moment as the container initializes)")
    
    # Wait a bit more for container to fully start
    time.sleep(10)
    
    ssh_cmd = f"ssh -o StrictHostKeyChecking=no -o ConnectTimeout=15 -o UserKnownHostsFile=/dev/null root@{ssh_host} -p {ssh_port}"
    
    try:
        # Check if smctm exists
        result = subprocess.run(
            f"{ssh_cmd} 'ls -la /workspace/smctm 2>&1'",
            shell=True,
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if "No such file" in result.stdout or "cannot access" in result.stdout or "not found" in result.stdout:
            print("   ⚠️  /workspace/smctm NOT FOUND yet")
            print("   The container may still be initializing. The entrypoint should clone it automatically.")
            print(f"\n   To check manually:")
            print(f"   {ssh_cmd}")
            print(f"   ls -la /workspace/")
            print(f"   ls -la /workspace/smctm/")
            return False
        else:
            print("   ✅ /workspace/smctm EXISTS!")
            print()
            
            # Get more details
            detail_result = subprocess.run(
                f"{ssh_cmd} 'cd /workspace/smctm && pwd && echo && git status 2>&1 | head -10'",
                shell=True,
                capture_output=True,
                text=True,
                timeout=30
            )
            
            print("   Details:")
            print(f"   {detail_result.stdout}")
            print("   ✅ smctm repository is successfully cloned!")
            return True
            
    except subprocess.TimeoutExpired:
        print("   ⚠️  SSH connection timed out (instance may still be starting)")
        print(f"   Please check manually: {ssh_cmd}")
        return False
    except Exception as e:
        print(f"   ⚠️  Could not check via SSH: {e}")
        print(f"   Please check manually: {ssh_cmd}")
        return False

if __name__ == "__main__":
    print("🚀 Creating Vast.ai Instance with Fast Internet")
    print("=" * 50)
    print(f"Template ID: {TEMPLATE_ID}")
    print(f"Image: {IMAGE}")
    print()
    
    # Step 1: Search for offers with high network speed
    offer_id = search_offers_high_speed()
    if not offer_id:
        print("\n❌ Could not find suitable offer")
        sys.exit(1)
    
    # Step 2: Create instance
    instance_id = create_instance(offer_id, TEMPLATE_ID)
    if not instance_id:
        print("\n❌ Could not create instance")
        sys.exit(1)
    
    # Step 3: Wait for instance to initialize
    print("\n⏳ Waiting 45 seconds for instance to initialize and container to start...")
    time.sleep(45)
    
    # Step 4: Get instance details
    instance_info = get_instance_details(instance_id)
    
    if instance_info:
        ssh_host = instance_info["host"]
        ssh_port = instance_info["port"]
        
        # Step 5: Check for smctm
        check_smctm(ssh_host, ssh_port)
        
        print(f"\n📝 Instance Details:")
        print(f"   Instance ID: {instance_id}")
        print(f"   SSH: ssh root@{ssh_host} -p {ssh_port}")
        print(f"   View in browser: https://console.vast.ai/instances")
    else:
        print(f"\n⚠️  Could not get instance details yet")
        print(f"   Instance ID: {instance_id}")
        print(f"   Check manually at: https://console.vast.ai/instances")
    
    print("\n✅ Done!")
