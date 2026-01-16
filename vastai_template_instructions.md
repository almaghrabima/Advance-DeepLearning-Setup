# Vast.ai Template Creation Instructions

This guide will help you create a Vast.ai template for the `advance-deeplearning` Docker image.

## Prerequisites

1. **Docker Image Built and Pushed**: Make sure you've built and pushed the Vast.ai-tagged image:
   ```bash
   ./build_and_push_vastai.sh
   ```
   This creates: `almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai`

2. **Vast.ai Account**: You need an active Vast.ai account with API access (for automated creation) or UI access (for manual creation).

## Method 1: Create Template via Vast.ai Web UI

### Step 1: Navigate to Templates
1. Log in to [Vast.ai Console](https://console.vast.ai)
2. Go to **Templates** → **My Templates**
3. Click **"+ New"** or **"Create Template"**

### Step 2: Template Identification
- **Template Name**: `advance-deeplearning-vastai` (or your preferred name)
- **Description**: `PyTorch 2.8 + CUDA 12.8 Deep Learning setup with Jupyter, SSH, and code-server`

### Step 3: Docker Repository and Environment
- **Image Path:Tag**: `almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai`
  - Use the full path including the tag
  - If using Docker Hub, you can use `docker.io/almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai`

### Step 4: Environment Variables
Add the following environment variables in the template settings:

```
GIT_USER_EMAIL=your_email@example.com
WANDB_API_KEY=your_wandb_api_key_here
PROJECT_REPO=https://github.com/yourusername/yourrepo.git
HF_HUB_ENABLE_HF_TRANSFER=1
GITHUB_PAT=your_github_pat_here
HUGGING_FACE_HUB_TOKEN=your_huggingface_token_here
GIT_USER_NAME=your_username
```

**Note**: Replace the placeholder values with your actual credentials. You can copy these from your `.env` file.

**Note**: In the UI, you may need to add these one by one or as a key-value pair list depending on the interface.

### Step 5: Port Mappings
Configure the following port mappings:
- **Port 8888** → **8888** (Jupyter Notebook)
- **Port 22** → **22** (SSH)
- **Port 13337** → **13337** (code-server, optional)
- **Port 6006** → **6006** (TensorBoard, optional)

In Vast.ai UI, ports are typically configured in a "Ports" or "Docker Options" section. You may need to add them as:
```
-p 8888:8888 -p 22:22 -p 13337:13337 -p 6006:6006
```

### Step 6: Launch Mode
- **Launch Mode**: Select **"Jupyter + SSH"** or **"Jupyter Lab + SSH"**
  - This enables both Jupyter notebook access and SSH access
  - Ensure `jup_direct` and `ssh_direct` are enabled if those options are available

### Step 7: On-Start Script (Optional)
If there's an "On-start Script" or "PROVISIONING_SCRIPT" field, you can add:
```bash
env >> /etc/environment || true
```
This ensures environment variables are available to all processes.

### Step 8: Jupyter Directory
- **Jupyter Directory**: `/workspace`
  - This sets the working directory for Jupyter notebooks

### Step 9: Save Template
- Click **"Save"** or **"Create & Use"** to save the template
- The template is now available for launching instances

## Method 2: Create Template via Vast.ai API

### Step 1: Get Your API Token
1. Go to [Vast.ai Settings](https://console.vast.ai/account)
2. Navigate to **API** section
3. Copy your API token

### Step 2: Use the Provided Script
Run the automated script:
```bash
export VAST_API_TOKEN='your_api_token_here'
./create_vastai_template.sh
```

Or manually use curl:
```bash
curl --request POST \
  --url https://console.vast.ai/api/v0/template/ \
  --header "Authorization: Bearer YOUR_VAST_API_TOKEN" \
  --header "Content-Type: application/json" \
  --data @vastai_template.json
```

Replace `YOUR_VAST_API_TOKEN` with your actual API token.

**Note**: The Vast.ai API expects the `env` field as a space-separated string of `KEY=VALUE` pairs, not a JSON object. The `vastai_template.json` file has been updated to use the correct format.

### Step 3: Verify Template Creation
The API will return a template ID if successful. You can verify by:
1. Checking the Vast.ai UI → Templates
2. Or querying the API: `GET https://console.vast.ai/api/v0/template/`

**Note**: Additional settings like `runtype`, `ssh_direct`, `jup_direct`, and port mappings may need to be configured via the Vast.ai UI after template creation, as these fields might not be supported in the initial template creation API call.

## Launching an Instance

### Via Web UI
1. Go to **Create** → **Instances**
2. Select your template: `advance-deeplearning-vastai`
3. Choose a GPU instance
4. Click **"Rent"** or **"Create"**

### Via API
```bash
curl --request POST \
  --url https://console.vast.ai/api/v0/asks/ \
  --header "Authorization: Bearer YOUR_VAST_API_TOKEN" \
  --header "Content-Type: application/json" \
  --data '{
    "template_id": YOUR_TEMPLATE_ID,
    "client_id": "me",
    "image": "almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai"
  }'
```

## Verification Checklist

After launching an instance, verify:

- [ ] **Jupyter Access**: Connect to Jupyter on port 8888 (link provided in Vast.ai instance page)
- [ ] **SSH Access**: SSH into the instance on port 22
- [ ] **Environment Variables**: Run `env | grep GIT_USER` to verify variables are set
- [ ] **Project Repository**: Check that the project repo is cloned in `/workspace`
- [ ] **Dependencies**: Verify Python packages are installed (check `.venv` directory)
- [ ] **code-server**: Access code-server on port 13337 (if configured)
- [ ] **GPU Access**: Run `nvidia-smi` to verify GPU is accessible

## Troubleshooting

### Image Not Found
- Verify the image is pushed to Docker Hub: `docker pull almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai`
- Check that the image path and tag are correct in the template

### Ports Not Accessible
- Verify port mappings in template settings
- Check Vast.ai firewall/network settings
- Ensure services are binding to `0.0.0.0` not `127.0.0.1`

### Environment Variables Not Set
- Add the onstart script: `env >> /etc/environment || true`
- Verify variables are set in template configuration
- Check container logs: `docker logs <container_id>`

### Jupyter Not Starting
- Verify launch mode includes Jupyter
- Check that `/start.sh` exists in the base image (from runpod/pytorch)
- Review container logs for errors

### Project Not Cloned
- Verify `PROJECT_REPO` environment variable is set correctly
- Check that `GITHUB_PAT` is valid if using private repos
- Review `start-project.sh` logs in container

## Additional Resources

- [Vast.ai Templates Documentation](https://docs.vast.ai/documentation/templates/introduction)
- [Vast.ai API Reference](https://docs.vast.ai/api-reference/templates)
- [Vast.ai FAQ](https://console.vast.ai/faq)
