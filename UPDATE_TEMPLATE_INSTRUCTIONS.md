# Update Template Onstart Script

## Quick Update

If you have the template hash:

```bash
./update_template_onstart_simple.sh <template_hash>
```

## Find Your Template Hash

### Method 1: From Vast.ai UI
1. Go to https://console.vast.ai/templates
2. Find your template "Advance DeepLearning Setup - 500GB"
3. Click on it to view details
4. The hash is in the URL or template details (32 character hex string)

### Method 2: From CLI
```bash
# List all templates and search for yours
vastai search templates | grep -A 10 "Advance\|almamoha"

# Or get raw JSON and search
vastai search templates --raw > templates.json
# Then search for your template ID or name in the file
```

### Method 3: Check Current Template
If you know your template has this onstart command:
```
bash -lc 'if [ -f /usr/local/bin/start-project.sh ]; then /usr/local/bin/start-project.sh; else start-project.sh; fi'
```

You can search for it:
```bash
vastai search templates --raw | grep -B 5 -A 5 "start-project.sh" | grep -E "(id|hash_id|name)"
```

## Update Command

Once you have the hash, run:

```bash
# Make sure .env file has all required variables
source .env

# Update the template
./update_template_onstart_simple.sh <template_hash>
```

## What Gets Updated

The onstart command will change from:
```bash
bash -lc 'if [ -f /usr/local/bin/start-project.sh ]; then /usr/local/bin/start-project.sh; else start-project.sh; fi'
```

To:
```bash
bash -c '/usr/local/bin/onstart.sh 2>&1 | tee -a /var/log/onstart.log; if [ -f /usr/local/bin/start-project.sh ]; then /usr/local/bin/start-project.sh; else start-project.sh; fi'
```

This ensures:
- ✅ Repository is cloned automatically on instance start
- ✅ Logs are saved to `/var/log/onstart.log`
- ✅ `start-project.sh` still runs after cloning

## Verify Update

After updating, create a new instance and check:
```bash
# SSH into instance
ssh root@<instance-ip> -p <port>

# Check onstart log
cat /var/log/onstart.log

# Verify repository was cloned
ls -la /workspace/smctm/
```
