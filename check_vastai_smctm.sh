#!/usr/bin/env bash
# Script to check Vast.ai instances and verify smctm project

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

echo "🔍 Checking Vast.ai Instances"
echo "=============================="
echo ""

# Try to get instances
RESPONSE=$(curl -s -X GET "https://cloud.vast.ai/api/v0/asks/" \
    -H "Authorization: Bearer $API_TOKEN" 2>/dev/null)

if echo "$RESPONSE" | grep -q '"asks"'; then
    echo "📊 Active Instances:"
    echo ""
    echo "$RESPONSE" | python3 << 'PYTHON'
import sys, json
try:
    data = json.load(sys.stdin)
    asks = data.get('asks', [])
    if not asks:
        print("  No active instances found")
        sys.exit(0)
    
    for i, ask in enumerate(asks, 1):
        print(f"Instance {i}:")
        print(f"  ID: {ask.get('id')}")
        print(f"  Status: {ask.get('state', 'unknown')}")
        print(f"  Image: {ask.get('image', 'N/A')}")
        
        ssh_host = ask.get('ssh_host')
        ssh_port = ask.get('ssh_port', 22)
        if ssh_host:
            print(f"  SSH: ssh root@{ssh_host} -p {ssh_port}")
        
        jupyter_url = ask.get('jupyter_url')
        if jupyter_url:
            print(f"  Jupyter: {jupyter_url}")
        
        print("")
        print("  To check for smctm project:")
        if ssh_host:
            print(f"    ssh root@{ssh_host} -p {ssh_port}")
            print("    cd /workspace")
            print("    ls -la")
            print("    ls -la smctm/  # Check if smctm exists")
            print("    env | grep PROJECT_REPO  # Check env vars")
        print("")
except Exception as e:
    print(f"  Error parsing response: {e}")
    print("  Raw response (first 500 chars):")
    print(sys.stdin.read()[:500])
PYTHON
else
    echo "❌ Could not retrieve instances or no instances found"
    echo ""
    echo "Response:"
    echo "$RESPONSE" | head -20
    echo ""
    echo "💡 To create an instance:"
    echo "  1. Go to: https://console.vast.ai/create"
    echo "  2. Select template: advance-deeplearning-vastai (ID: 329609)"
    echo "  3. Choose a GPU and click 'Rent'"
    echo ""
    echo "📝 After instance is created, verify smctm access:"
    echo "  - SSH into the instance"
    echo "  - Run: ls -la /workspace/smctm/"
    echo "  - Run: cd /workspace/smctm && git status"
fi
