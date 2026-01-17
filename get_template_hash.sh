#!/usr/bin/env bash
# Get template hash for templates matching specific criteria

VASTAI_CMD="/opt/homebrew/bin/vastai"

echo "🔍 Searching for your template..."
echo ""

# Search for templates and filter
$VASTAI_CMD search templates 2>&1 | python3 << 'PYTHON'
import sys
import json

try:
    data = json.load(sys.stdin)
    templates = data if isinstance(data, list) else []
    
    found = False
    for template in templates:
        name = template.get('name', '')
        image = template.get('image', '')
        onstart = template.get('onstart', '')
        template_id = template.get('id', '')
        hash_id = template.get('hash_id', '')
        
        # Check if it matches our criteria
        if ('advance' in name.lower() or 'deeplearning' in name.lower() or 
            'almamoha' in image.lower() or 
            'start-project.sh' in onstart):
            print(f"✅ Found Template:")
            print(f"   ID: {template_id}")
            print(f"   Hash: {hash_id}")
            print(f"   Name: {name}")
            print(f"   Image: {image}")
            print(f"   Onstart: {onstart[:100]}...")
            print()
            found = True
    
    if not found:
        print("❌ No matching template found")
        print("\nAll your templates:")
        for template in templates[:10]:  # Show first 10
            print(f"   ID: {template.get('id')}, Name: {template.get('name')}, Hash: {template.get('hash_id')}")
            
except Exception as e:
    print(f"Error: {e}")
    print("\nTrying alternative search...")
    # Fallback: just show raw output
    sys.stdin.seek(0)
    content = sys.stdin.read()
    if 'start-project.sh' in content:
        print("Found 'start-project.sh' in templates, but couldn't parse JSON")
        print("Please check Vast.ai UI for the template hash")

PYTHON
