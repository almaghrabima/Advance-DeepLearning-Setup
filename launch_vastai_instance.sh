#!/usr/bin/env bash
# Script to launch Vast.ai instance and check for smctm project

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

echo "🚀 Vast.ai Instance Launcher"
echo "=============================="
echo ""
echo "Template ID: $TEMPLATE_ID"
echo "Image: $IMAGE"
echo ""

echo "📝 Instructions to create instance via Web UI:"
echo "1. Go to: https://console.vast.ai/create"
echo "2. Select template ID: $TEMPLATE_ID (or search for 'advance-deeplearning-vastai')"
echo "3. Choose a GPU instance"
echo "4. Click 'Rent' or 'Create'"
echo "5. Wait for instance to start"
echo "6. Note the SSH connection details from the instance page"
echo ""

echo "🔍 Checking existing instances..."
INSTANCES=$(curl -s -X GET "https://cloud.vast.ai/api/v0/asks/" \
    -H "Authorization: Bearer $API_TOKEN" 2>/dev/null || echo "{}")

if echo "$INSTANCES" | grep -q '"asks"'; then
    echo "✅ Found existing instances:"
    echo "$INSTANCES" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    asks = data.get('asks', [])
    for ask in asks[:5]:
        print(f\"  ID: {ask.get('id')}, Status: {ask.get('state', 'unknown')}, Image: {ask.get('image', 'N/A')[:50]}\")
        if ask.get('ssh_host'):
            print(f\"    SSH: ssh root@{ask.get('ssh_host')} -p {ask.get('ssh_port', 22)}\")
except:
    print('  Could not parse instances')
" 2>/dev/null || echo "  Could not parse response"
else
    echo "  No instances found or API error"
fi

echo ""
echo "📋 To check for smctm after connecting via SSH:"
echo "  ssh root@<host> -p <port>"
echo "  cd /workspace"
echo "  ls -la"
echo "  ls -la smctm/  # Check if smctm directory exists"
echo "  cat smctm/README.md  # If it exists"
