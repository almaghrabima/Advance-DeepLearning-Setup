# Vast.ai CLI Usage Guide

Based on the [Vast.ai CLI Commands Documentation](https://docs.vast.ai/cli/commands), here's how to create an instance and verify smctm.

## Prerequisites

The Vast.ai CLI requires **Python 3.10+**. Your system has Python 3.9, so you have two options:

### Option 1: Install Python 3.10+ (Recommended)

```bash
# Using Homebrew (macOS)
brew install python@3.11

# Then install vastai with the new Python
python3.11 -m pip install vastai
python3.11 -m vastai --help
```

### Option 2: Use API Directly (Current Workaround)

Since the CLI has Python version issues, use the scripts provided or API calls directly.

## CLI Commands (Once Python 3.10+ is Available)

### 1. Set API Key

```bash
# Load from .env file
source .env
vastai set api-key "${VAST_API_TOKEN}"

# Or set directly
vastai set api-key your_vast_api_token_here
```

### 2. Search for Offers

```bash
# Search for on-demand GPU offers
vastai search offers 'on-demand==True' --limit 5

# Search with specific GPU
vastai search offers 'gpu_name==RTX_3090 on-demand==True'
```

### 3. Create Instance from Template

According to the [CLI documentation](https://docs.vast.ai/cli/commands), use:

```bash
vastai create instance <offer_id> \
  --image almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai \
  --template 329499 \
  --ssh
```

Or use `launch instance` which automatically selects the best offer:

```bash
vastai launch instance \
  --image almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai \
  --template 329499 \
  --on-demand \
  --ssh
```

### 4. Show Instances

```bash
# List all instances
vastai show instances

# Show specific instance
vastai show instance <instance_id>
```

### 5. Get SSH Connection

```bash
# Get SSH URL for an instance
vastai ssh-url <instance_id>

# Or show full instance details
vastai show instance <instance_id>
```

### 6. Connect and Verify smctm

```bash
# Connect via SSH (use details from ssh-url command)
ssh root@<host> -p <port>

# Once connected, check for smctm
cd /workspace
ls -la smctm/
env | grep PROJECT_REPO
```

## Alternative: Using Web UI

Since the CLI has Python version compatibility issues, the web UI is currently the most reliable method:

1. Go to https://console.vast.ai/create
2. Search for template: **329499** or **advance-deeplearning-vastai**
3. Select a GPU instance
4. Click "Rent"
5. Once running, get SSH details from the instance page
6. Connect and verify smctm

## Template Details

- **Template ID**: 329499
- **Template Name**: advance-deeplearning-vastai  
- **Docker Image**: almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai
- **Environment Variables**: All configured in template (GIT_USER_EMAIL, WANDB_API_KEY, PROJECT_REPO, etc.)

## Verification Steps

After connecting to your instance:

```bash
# 1. Check if smctm directory exists
cd /workspace
ls -la smctm/

# 2. Verify environment variables
env | grep GIT_USER
env | grep PROJECT_REPO
env | grep WANDB_API_KEY

# 3. Check if project was cloned
cd smctm
git status
git remote -v

# 4. Check if dependencies are installed
ls -la .venv/
source .venv/bin/activate
pip list | head -20

# 5. Verify services are running
ps aux | grep jupyter
ps aux | grep code-server
netstat -tuln | grep -E '8888|13337'
```

## Troubleshooting

### CLI Python Version Error

If you see: `TypeError: unsupported operand type(s) for |: 'types.GenericAlias' and 'NoneType'`

**Solution**: Install Python 3.10+ and use that version for vastai:
```bash
brew install python@3.11
python3.11 -m pip install vastai
```

### Instance Not Starting

- Check instance status: `vastai show instance <id>`
- Check logs: `vastai logs <instance_id>`
- Verify template exists: `vastai search templates 'id==329499'`

### smctm Not Found

- Check if start script ran: `ps aux | grep start-project`
- Check logs: `docker logs <container_id>` or check `/tmp/start-project.log`
- Manually clone if needed:
  ```bash
  cd /workspace
  # Load from .env file or set manually
  source .env
  export GITHUB_PAT="${GITHUB_PAT}"
  git clone https://${GITHUB_PAT}@github.com/yourusername/yourrepo.git
  ```

## Reference

- [Vast.ai CLI Commands Documentation](https://docs.vast.ai/cli/commands)
- [Vast.ai API Reference](https://docs.vast.ai/api-reference/overview-and-quickstart)
