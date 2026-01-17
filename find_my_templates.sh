#!/usr/bin/env bash
# Find your Vast.ai templates that have environment variables configured

set -euo pipefail

VASTAI_CMD="/opt/homebrew/bin/vastai"

echo "🔍 Finding Your Templates with Environment Variables"
echo "===================================================="
echo ""

# Get templates in raw format and parse
echo "Searching for templates..."
TEMPLATE_OUTPUT=$($VASTAI_CMD search templates --raw 2>&1)

# Parse templates using Python
echo "$TEMPLATE_OUTPUT" | python3 << 'PYTHON'
import sys
import json
import re

try:
    content = sys.stdin.read()
    
    # Try to parse as JSON
    try:
        data = json.loads(content)
        templates = data if isinstance(data, list) else data.get('templates', [])
    except json.JSONDecodeError:
        # If not valid JSON, try to extract JSON objects
        templates = []
        # Look for JSON objects in the output
        json_pattern = r'\{[^{}]*"id"[^{}]*\}'
        matches = re.findall(json_pattern, content, re.DOTALL)
        for match in matches:
            try:
                templates.append(json.loads(match))
            except:
                pass
    
    if not templates:
        # Last resort: try to find template IDs and names manually
        print("⚠️  Could not parse JSON, trying alternative method...")
        # Look for template patterns
        id_pattern = r'"id":\s*(\d+)'
        name_pattern = r'"name":\s*"([^"]+)"'
        env_pattern = r'"env":\s*"([^"]+)"'
        
        ids = re.findall(id_pattern, content)
        # This is a fallback - we'll just show what we can find
        print(f"Found {len(ids)} potential template IDs")
        for i, tid in enumerate(ids[:10], 1):
            print(f"  {i}. Template ID: {tid}")
        sys.exit(0)
    
    # Search for templates
    matches = []
    for template in templates:
        template_id = template.get('id', '')
        name = str(template.get('name', '')).lower()
        image = str(template.get('image', '')).lower()
        env = str(template.get('env', ''))
        
        # Check if it matches our criteria
        is_our_template = (
            'advance' in name or 
            'deeplearning' in name or 
            'almamoha' in image or
            'advance-deeplearning' in image
        )
        
        # Check if it has environment variables
        has_env = (
            'GITHUB_REPO' in env or 
            'PROJECT_REPO' in env or 
            'GITHUB_PAT' in env
        )
        
        if is_our_template or has_env:
            matches.append({
                'id': template_id,
                'name': template.get('name', 'N/A'),
                'image': template.get('image', 'N/A'),
                'has_env': has_env,
                'is_our_template': is_our_template
            })
    
    if matches:
        print(f"✅ Found {len(matches)} matching template(s):\n")
        for i, match in enumerate(matches, 1):
            status = "✅ Has env vars" if match['has_env'] else "⚠️  No env vars"
            template_type = "🎯 Your template" if match['is_our_template'] else "📋 Other"
            print(f"{i}. {template_type}")
            print(f"   ID: {match['id']}")
            print(f"   Name: {match['name']}")
            print(f"   Image: {match['image']}")
            print(f"   {status}")
            print("")
        
        # Find the best match (our template with env vars)
        best_match = next((m for m in matches if m['is_our_template'] and m['has_env']), None)
        if not best_match:
            best_match = next((m for m in matches if m['has_env']), None)
        
        if best_match:
            print(f"🎯 Recommended Template ID: {best_match['id']}")
            print(f"   Name: {best_match['name']}")
            print("")
            print("To use this template:")
            print(f"   ./recreate_with_template.sh 30136620 {best_match['id']}")
    else:
        print("❌ No matching templates found")
        print("")
        print("💡 You may need to:")
        print("   1. Create a template with environment variables")
        print("   2. Or manually clone smctm on the current instance")
        print("")
        print("To create a template:")
        print("   ./create_template_complete.sh")

except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYTHON

echo ""
echo "📝 Alternative: Check templates in Vast.ai UI:"
echo "   https://console.vast.ai/templates"
echo ""
