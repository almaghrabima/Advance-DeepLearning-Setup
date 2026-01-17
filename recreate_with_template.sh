#!/usr/bin/env bash
# Recreate instance WITH a template that has environment variables configured

set -euo pipefail

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

VASTAI_CMD="/opt/homebrew/bin/vastai"
CURRENT_INSTANCE_ID="${1:-30136620}"

echo "🔄 Recreate Instance with Template"
echo "==================================="
echo "Current Instance: $CURRENT_INSTANCE_ID"
echo ""

# Check if API token is available
if [ -z "${VAST_API_TOKEN:-}" ]; then
    echo "⚠️  Warning: VAST_API_TOKEN not set. Some commands may fail."
    echo "   Set it in your .env file or export it."
    echo ""
fi

echo "🔍 Step 1: Finding templates with environment variables..."
echo ""

# Search for templates
TEMPLATE_SEARCH=$($VASTAI_CMD search templates --raw 2>&1 | python3 << 'PYTHON'
import sys
import json

try:
    # Try to parse as JSON
    content = sys.stdin.read()
    
    # Try to parse as JSON array or object
    try:
        data = json.loads(content)
        templates = data if isinstance(data, list) else data.get('templates', [])
    except:
        # If not JSON, try to extract template info
        templates = []
        # Look for template patterns in the output
        import re
        # This is a fallback - vast.ai CLI might return formatted text
        print("⚠️  Could not parse as JSON, trying alternative method...")
        sys.exit(1)
    
    # Find templates with advance-deeplearning or almamoha
    matches = []
    for template in templates:
        name = str(template.get('name', '')).lower()
        image = str(template.get('image', '')).lower()
        template_id = template.get('id', '')
        env = str(template.get('env', ''))
        
        if ('advance' in name or 'deeplearning' in name or 
            'almamoha' in image or 'advance-deeplearning' in image):
            # Check if it has environment variables
            has_env = ('GITHUB_REPO' in env or 'PROJECT_REPO' in env or 
                      'GITHUB_PAT' in env)
            matches.append({
                'id': template_id,
                'name': template.get('name', 'N/A'),
                'image': template.get('image', 'N/A'),
                'has_env': has_env
            })
    
    if matches:
        for match in matches[:5]:
            status = "✅ Has env vars" if match['has_env'] else "⚠️  No env vars"
            print(f"ID: {match['id']}, Name: {match['name']}, {status}")
            if match['has_env']:
                print(f"   Image: {match['image']}")
                # Save the first good template
                with open('/tmp/vastai_template_id.txt', 'w') as f:
                    f.write(str(match['id']))
                break
    else:
        print("❌ No matching templates found")
        sys.exit(1)
        
except Exception as e:
    print(f"❌ Error: {e}")
    sys.exit(1)
PYTHON
)

if [ -f /tmp/vastai_template_id.txt ]; then
    TEMPLATE_ID=$(cat /tmp/vastai_template_id.txt)
    echo ""
    echo "✅ Found template with environment variables: $TEMPLATE_ID"
else
    echo ""
    echo "⚠️  Could not automatically find template. Using default: 329609"
    echo "   You can specify a template ID as the second argument"
    TEMPLATE_ID="${2:-329609}"
fi

echo ""
echo "📋 Template ID: $TEMPLATE_ID"
echo ""

# Confirm
read -p "⚠️  This will destroy instance $CURRENT_INSTANCE_ID and create a new one with template $TEMPLATE_ID. Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cancelled"
    exit 1
fi

# Destroy current instance
echo ""
echo "🗑️  Destroying instance $CURRENT_INSTANCE_ID..."
$VASTAI_CMD destroy instance $CURRENT_INSTANCE_ID 2>&1 || echo "Instance may already be destroyed"
echo ""

# Wait
echo "⏳ Waiting 10 seconds..."
sleep 10

# Search for offers
echo "🔍 Searching for offers..."
OFFER_OUTPUT=$($VASTAI_CMD search offers --limit 5 2>&1)
OFFER_LINE=$(echo "$OFFER_OUTPUT" | grep -E "^[0-9]" | head -1)
OFFER_ID=$(echo "$OFFER_LINE" | awk '{print $1}')

if [ -z "$OFFER_ID" ] || ! [[ "$OFFER_ID" =~ ^[0-9]+$ ]]; then
    echo "❌ Could not find suitable offer"
    exit 1
fi

echo "✅ Selected offer: $OFFER_ID"
echo ""

# Create instance WITH template
echo "🚀 Creating instance with template $TEMPLATE_ID..."
CREATE_OUTPUT=$($VASTAI_CMD create instance $OFFER_ID \
    --image almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai \
    --template $TEMPLATE_ID \
    --ssh 2>&1)

echo "$CREATE_OUTPUT"
echo ""

# Extract new instance ID
NEW_INSTANCE_ID=$(echo "$CREATE_OUTPUT" | python3 << 'PYTHON'
import sys
import re

content = sys.stdin.read()
patterns = [
    r"'new_contract':\s*(\d+)",
    r'"new_contract":\s*(\d+)',
    r"new_contract['\"]?\s*:\s*(\d+)",
]

for pattern in patterns:
    match = re.search(pattern, content)
    if match:
        print(match.group(1))
        sys.exit(0)

print("")
PYTHON
)

if [ -n "$NEW_INSTANCE_ID" ]; then
    echo "✅ New instance created: $NEW_INSTANCE_ID"
    echo ""
    echo "⏳ Waiting 30 seconds for instance to initialize..."
    sleep 30
    echo ""
    echo "📊 Instance status:"
    $VASTAI_CMD show instance $NEW_INSTANCE_ID 2>&1 | head -10
    echo ""
    echo "🔐 SSH connection:"
    $VASTAI_CMD ssh-url $NEW_INSTANCE_ID 2>&1
    echo ""
    echo "📝 After instance starts, check for smctm:"
    echo "   ssh root@<host> -p <port>"
    echo "   ls -la /workspace/smctm/"
    echo "   env | grep PROJECT_REPO"
else
    echo "⚠️  Could not extract instance ID. Check manually:"
    echo "   $VASTAI_CMD show instances"
fi
