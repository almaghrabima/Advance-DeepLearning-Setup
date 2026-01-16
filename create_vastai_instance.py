#!/usr/bin/env python3
"""Create a Vast.ai instance from template and get connection details"""
import json
import os
import sys
import time
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables from .env file
env_path = Path(__file__).parent / '.env'
load_dotenv(env_path)

API_TOKEN = os.getenv("VAST_API_TOKEN")
if not API_TOKEN:
    print("❌ Error: VAST_API_TOKEN not found in environment variables")
    print("   Please create a .env file with VAST_API_TOKEN (see .env.example)")
    sys.exit(1)

API_BASE = "https://cloud.vast.ai/api/v0"
HEADERS = {
    "Authorization": f"Bearer {API_TOKEN}",
    "Content-Type": "application/json"
}

def search_offers():
    """Search for available on-demand offers"""
    print("🔍 Searching for available offers...")
    response = requests.get(f"{API_BASE}/offers/", headers=HEADERS, params={"q": "on-demand"})
    if response.status_code != 200:
        print(f"❌ Error searching offers: {response.status_code}")
        print(response.text)
        return None
    
    data = response.json()
    offers = data.get("offers", [])
    on_demand = [o for o in offers if o.get("on_demand")]
    
    if not on_demand:
        print("❌ No on-demand offers found")
        return None
    
    # Sort by price and return first one
    on_demand.sort(key=lambda x: x.get("dph_total", 0))
    offer = on_demand[0]
    
    print(f"✅ Found offer: ID={offer.get('id')}, GPU={offer.get('gpu_name', 'N/A')}, "
          f"Price=${offer.get('dph_total', 0):.2f}/hr")
    return offer.get("id")

def create_instance(offer_id, template_id):
    """Create an instance from template"""
    print(f"\n🚀 Creating instance from template {template_id} on offer {offer_id}...")
    
    payload = {
        "client_id": "me",
        "template_id": template_id,
        "image": "almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai"
    }
    
    response = requests.put(f"{API_BASE}/asks/{offer_id}", headers=HEADERS, json=payload)
    
    if response.status_code in [200, 201]:
        data = response.json()
        print("✅ Instance created successfully!")
        print(json.dumps(data, indent=2))
        return data.get("new_contract") or data.get("id")
    else:
        print(f"❌ Error creating instance: {response.status_code}")
        print(response.text)
        return None

def get_instance_status(instance_id):
    """Get instance status and connection details"""
    print(f"\n📊 Checking instance status...")
    response = requests.get(f"{API_BASE}/asks/", headers=HEADERS)
    
    if response.status_code != 200:
        print(f"❌ Error getting instances: {response.status_code}")
        return None
    
    data = response.json()
    instances = data.get("asks", [])
    
    # Find our instance
    instance = None
    for inst in instances:
        if str(inst.get("id")) == str(instance_id) or str(inst.get("job_id")) == str(instance_id):
            instance = inst
            break
    
    if not instance:
        print(f"❌ Instance {instance_id} not found")
        return None
    
    print(f"✅ Instance found:")
    print(f"   Status: {instance.get('state', 'unknown')}")
    print(f"   SSH: {instance.get('ssh_host', 'N/A')}:{instance.get('ssh_port', 'N/A')}")
    print(f"   Jupyter: {instance.get('jupyter_url', 'N/A')}")
    
    return instance

if __name__ == "__main__":
    template_id = 329499
    
    # Search for offers
    offer_id = search_offers()
    if not offer_id:
        print("\n❌ Could not find suitable offer")
        sys.exit(1)
    
    # Create instance
    instance_id = create_instance(offer_id, template_id)
    if not instance_id:
        print("\n❌ Could not create instance")
        sys.exit(1)
    
    # Wait a bit for instance to start
    print("\n⏳ Waiting 10 seconds for instance to initialize...")
    time.sleep(10)
    
    # Get status
    instance = get_instance_status(instance_id)
    
    if instance:
        print("\n📝 Connection details:")
        if instance.get("ssh_host"):
            print(f"   SSH: ssh root@{instance.get('ssh_host')} -p {instance.get('ssh_port', 22)}")
        if instance.get("jupyter_url"):
            print(f"   Jupyter: {instance.get('jupyter_url')}")
