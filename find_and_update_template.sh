#!/usr/bin/env bash
# Find template by onstart command and update it

set -euo pipefail

# Load environment variables from .env file
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

VASTAI_CMD="/opt/homebrew/bin/vastai"

echo "🔍 Searching for template with old onstart command..."
echo ""

# Search for templates and find the one with the specific onstart command
TEMPLATE_INFO=$($VASTAI_CMD search templates --raw 2>&1 | python3 << 'PYTHON'
import sys
import json
import re

try:
    # Read all input
    content = sys.stdin.read()
    
    # Try to parse as JSON array
    try:
        templates = json.loads(content)
        if not isinstance(templates, list):
            templates = [templates]
    except:
        # If not valid JSON, try to extract JSON objects
        templates = []
        # Find all JSON objects in the content
        for match in re.finditer(r'\{[^{}]*"id"[^{}]*\}', content):
            try:
                obj = json.loads(match.group(0))
                templates.append(obj)
            except:
                pass
    
    # Search for template with the specific onstart command
    target_onstart = "start-project.sh"
    
    for template in templates:
        onstart = template.get('onstart', '')
        name = template.get('name', '')
        template_id = template.get('id', '')
        hash_id = template.get('hash_id', '')
        image = template.get('image', '')
        
        # Check if it matches our criteria
        if (target_onstart in onstart and 
            ('advance' in name.lower() or 'deeplearning' in name.lower() or 
             'almamoha' in image.lower() or '329625' in str(template_id))):
            print(f"ID:{template_id}|HASH:{hash_id}|NAME:{name}|IMAGE:{image}")
            break
    else:
        # If not found, try to find by image
        for template in templates:
            image = template.get('image', '')
            if 'almamoha/advance-deeplearning' in image:
                onstart = template.get('onstart', '')
                name = template.get('name', '')
                template_id = template.get('id', '')
                hash_id = template.get('hash_id', '')
                print(f"ID:{template_id}|HASH:{hash_id}|NAME:{name}|IMAGE:{image}")
                break
        else:
            print("NOT_FOUND")
            
except Exception as e:
    print(f"ERROR:{e}")

PYTHON
)

if [ -z "$TEMPLATE_INFO" ] || [ "$TEMPLATE_INFO" = "NOT_FOUND" ] || [[ "$TEMPLATE_INFO" == ERROR* ]]; then
    echo "❌ Could not find template automatically"
    echo ""
    echo "Please provide the template hash manually:"
    echo "  1. Go to Vast.ai UI: https://console.vast.ai/templates"
    echo "  2. Find your template"
    echo "  3. Get the hash from the URL or template details"
    echo "  4. Run: ./update_template_onstart_simple.sh <hash>"
    exit 1
fi

# Parse the template info
TEMPLATE_ID=$(echo "$TEMPLATE_INFO" | cut -d'|' -f1 | cut -d':' -f2)
TEMPLATE_HASH=$(echo "$TEMPLATE_INFO" | cut -d'|' -f2 | cut -d':' -f2)
TEMPLATE_NAME=$(echo "$TEMPLATE_INFO" | cut -d'|' -f3 | cut -d':' -f2)
TEMPLATE_IMAGE=$(echo "$TEMPLATE_INFO" | cut -d'|' -f4 | cut -d':' -f2)

echo "✅ Found template:"
echo "   ID: $TEMPLATE_ID"
echo "   Hash: $TEMPLATE_HASH"
echo "   Name: $TEMPLATE_NAME"
echo "   Image: $TEMPLATE_IMAGE"
echo ""

# Now update it using the simple script
echo "🚀 Updating template with new onstart script..."
./update_template_onstart_simple.sh "$TEMPLATE_HASH"
