# Vast.ai Template 329625 - Summary

## Template Configuration

**Template ID**: `329625`  
**Name**: `advance-deeplearning-500gb-volume`

### Disk Configuration
- **Container Disk**: 500 GB
- **Volume Disk**: 500 GB (configured at instance creation)
- **Volume Mount Path**: `/workspace`

### Port Mappings
- **HTTP Ports**: 
  - `8888` (Jupyter Notebook)
  - `6006` (TensorBoard)
- **TCP Ports**:
  - `22` (SSH)

### Docker Image
- **Image**: `almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai`

### Environment Variables (from .env)
All environment variables are loaded from your local `.env` file:
- `GIT_USER_EMAIL`
- `WANDB_API_KEY`
- `PROJECT_REPO` (defaults to: https://github.com/almaghrabima/smctm.git)
- `GITHUB_REPO` (defaults to PROJECT_REPO if not set)
- `HF_HUB_ENABLE_HF_TRANSFER=1`
- `GITHUB_PAT`
- `HUGGING_FACE_HUB_TOKEN`
- `GIT_USER_NAME`

### Connection Settings
- **SSH**: Direct connections enabled
- **Run Type**: SSH instance

## Creating an Instance

### Method 1: Using the Helper Script

```bash
# Find an offer
vastai search offers --limit 5

# Create instance with volume (500GB mounted at /workspace)
./create_instance_with_volume.sh <offer_id> 329625
```

### Method 2: Using Vast.ai CLI Directly

```bash
# Search for volume offers (500GB)
vastai search volumes

# Create instance with volume
vastai create instance <offer_id> \
  --template 329625 \
  --disk 500 \
  --create-volume <volume_offer_id> \
  --volume-size 500 \
  --mount-path /workspace \
  --ssh \
  --direct
```

### Method 3: Without Volume (Volume can be added later)

```bash
vastai create instance <offer_id> \
  --template 329625 \
  --disk 500 \
  --ssh \
  --direct
```

## Verifying the Instance

After the instance is created:

1. **Get SSH connection details:**
   ```bash
   vastai ssh-url <instance_id>
   ```

2. **Connect via SSH:**
   ```bash
   ssh root@<host> -p <port>
   ```

3. **Verify volume mount:**
   ```bash
   df -h | grep workspace
   ls -la /workspace/
   ```

4. **Check environment variables:**
   ```bash
   env | grep GIT_USER
   env | grep WANDB
   env | grep PROJECT_REPO
   ```

5. **Verify ports are exposed:**
   ```bash
   netstat -tlnp | grep -E "8888|6006|22"
   ```

## Template Features

✅ 500GB container disk space  
✅ 500GB volume mount at `/workspace` (when created with volume)  
✅ Port mappings: 8888, 6006 (HTTP), 22 (TCP)  
✅ Environment variables from `.env` file  
✅ Direct SSH connections  
✅ Verified machines only  
✅ Automatic repository cloning (via entrypoint.sh)

## Notes

- The volume (500GB) is configured at **instance creation time**, not in the template itself
- If you create an instance without specifying a volume, you can add one later
- All environment variables are loaded from your local `.env` file
- The template uses the Docker image: `almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai`
