# Vast.ai Instance Creation and Verification Guide

## Quick Start: Create Instance via Web UI

Since the Vast.ai API endpoints can be finicky, the web UI is the most reliable method:

### Step 1: Create Instance
1. Go to [Vast.ai Create Page](https://console.vast.ai/create)
2. In the template search, enter: **329499** or **advance-deeplearning-vastai**
3. Select the template
4. Choose a GPU instance (any available GPU will work)
5. Click **"Rent"** or **"Create"**
6. Wait for the instance to start (usually 1-2 minutes)

### Step 2: Get Connection Details
Once the instance is running:
1. Go to [Vast.ai Instances](https://console.vast.ai/instances)
2. Find your instance
3. Note the **SSH** connection details:
   - Host: `ssh.vast.ai` or similar
   - Port: Usually `22` or a custom port
   - Username: Usually `root`

### Step 3: Connect and Verify smctm

```bash
# Connect via SSH (replace with your actual details)
ssh root@<ssh_host> -p <ssh_port>

# Once connected, check for smctm project
cd /workspace
ls -la

# Check if smctm directory exists
ls -la smctm/

# Verify environment variables
env | grep PROJECT_REPO
env | grep GIT_USER

# Check if project was cloned
if [ -d "smctm" ]; then
    echo "✅ smctm project found!"
    cd smctm
    git status
    ls -la
else
    echo "❌ smctm project not found"
    echo "Checking if start script ran..."
    ps aux | grep start-project
    cat /tmp/start-project.log 2>/dev/null || echo "No log found"
fi
```

## Alternative: Using Vast.ai CLI (if working)

If you have the Vast.ai CLI working:

```bash
# Set API key (load from .env file)
source .env
export VAST_API_KEY="${VAST_API_TOKEN}"

# Search for offers
vastai search offers --limit 5

# Create instance from template
vastai create instance <offer_id> \
  --image almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai \
  --template 329499 \
  --ssh

# List instances
vastai show instances

# Get SSH command
vastai ssh-url <instance_id>
```

## Verification Checklist

After connecting to your instance, verify:

- [ ] **Docker image is running**: `docker ps` or check processes
- [ ] **Environment variables are set**: `env | grep GIT_USER`, `env | grep WANDB_API_KEY`
- [ ] **smctm project exists**: `ls -la /workspace/smctm/`
- [ ] **Project was cloned correctly**: `cd /workspace/smctm && git status`
- [ ] **Dependencies installed**: `cd /workspace/smctm && ls -la .venv/`
- [ ] **Jupyter is accessible**: Check if port 8888 is listening
- [ ] **code-server is running**: Check if port 13337 is listening

## Troubleshooting

### smctm Not Found

If the smctm project is not in `/workspace`:

1. **Check if start script ran**:
   ```bash
   ps aux | grep start-project
   cat /var/log/start-project.log 2>/dev/null
   ```

2. **Manually clone the project**:
   ```bash
   cd /workspace
   # Load from .env file or set manually
   export GITHUB_PAT="your_github_pat_here"
   git clone https://${GITHUB_PAT}@github.com/yourusername/yourrepo.git
   ```

3. **Check environment variables**:
   ```bash
   echo $PROJECT_REPO
   echo $GITHUB_PAT
   ```

### Environment Variables Not Set

If environment variables are missing:

1. **Check template configuration** in Vast.ai UI
2. **Manually export them** (or load from .env file):
   ```bash
   # Option 1: Load from .env file
   source .env
   
   # Option 2: Set manually
   export GIT_USER_EMAIL="your_email@example.com"
   export WANDB_API_KEY="your_wandb_api_key_here"
   export PROJECT_REPO="https://github.com/yourusername/yourrepo.git"
   # ... etc
   ```

### Docker Container Not Starting

1. **Check container logs**:
   ```bash
   docker logs <container_id>
   ```

2. **Check if image was pulled**:
   ```bash
   docker images | grep advance-deeplearning
   ```

## Template Details

- **Template ID**: 329499
- **Template Name**: advance-deeplearning-vastai
- **Docker Image**: almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai
- **Base Image**: runpod/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04

## Next Steps

Once verified:
1. The smctm project should be in `/workspace/smctm/`
2. Dependencies should be installed in `.venv/`
3. Jupyter should be accessible on port 8888
4. You can start working on your project!
