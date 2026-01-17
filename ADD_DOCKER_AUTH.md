# Adding Docker Repository Authentication to Template 329625

## Current Status
Template ID: **329625**  
Name: **Advance DeepLearning Setup - 500GB (PyTorch 2.8 + CUDA 12.8)**

## Docker Credentials
- **Username**: `almamoha`
- **Password/Token**: `YOUR_DOCKER_PAT` (store in `.env` file as `DOCKER_PAT`)
- **Registry**: `docker.io`
- **Image**: `almamoha/advance-deeplearning:torch2.8-cuda12.8-vastai`

## Method 1: Via Vast.ai Web UI (Recommended)

1. Go to https://console.vast.ai/templates
2. Find template **329625** or search for "Advance DeepLearning Setup"
3. Click on the template to edit it
4. Look for **"Docker Repository Authentication"** or **"Docker Login"** section
5. Enter:
   - **Username**: `almamoha`
   - **Password**: `YOUR_DOCKER_PAT` (from `.env` file)
   - **Registry**: `docker.io` (or leave default)
6. Save the template

## Method 2: Via CLI (Requires Current Template Hash)

The template hash changes with each update. To find the current hash:

1. Go to https://console.vast.ai/templates
2. Find template 329625
3. Look at the URL or template details to find the `hash_id`
4. Or use the CLI to search (may be slow):
   ```bash
   vastai search templates --raw | grep -A 20 "329625"
   ```

Once you have the current hash, run:

```bash
cd /Users/mohammedalmaghrabi/Documents/code/Advance-DeepLearning-Setup
source .env

# Replace HASH_ID with the current template hash
vastai update template HASH_ID \
  --login "-u almamoha -p \${DOCKER_PAT} docker.io" \
  --name "Advance DeepLearning Setup - 500GB (PyTorch 2.8 + CUDA 12.8)" \
  --env "-p 8888:8888 -p 6006:6006 -p 22:22 -e GIT_USER_EMAIL=${GIT_USER_EMAIL} -e WANDB_API_KEY=${WANDB_API_KEY} -e PROJECT_REPO=${PROJECT_REPO} -e GITHUB_REPO=${GITHUB_REPO} -e HF_HUB_ENABLE_HF_TRANSFER=1 -e GITHUB_PAT=${GITHUB_PAT} -e HUGGING_FACE_HUB_TOKEN=${HUGGING_FACE_HUB_TOKEN} -e GIT_USER_NAME=${GIT_USER_NAME}" \
  --onstart-cmd "bash -lc 'if [ -f /usr/local/bin/start-project.sh ]; then /usr/local/bin/start-project.sh; else start-project.sh; fi'" \
  --ssh \
  --direct \
  --disk_space 500
```

## Method 3: Create New Template with Docker Auth

If updating is problematic, create a new template with all settings:

```bash
cd /Users/mohammedalmaghrabi/Documents/code/Advance-DeepLearning-Setup
source .env

vastai create template \
  --name "Advance DeepLearning Setup - 500GB (PyTorch 2.8 + CUDA 12.8)" \
  --image "almamoha/advance-deeplearning" \
  --image_tag "torch2.8-cuda12.8-vastai" \
  --login "-u almamoha -p \${DOCKER_PAT} docker.io" \
  --disk_space 500 \
  --ssh \
  --direct \
  --env "-p 8888:8888 -p 6006:6006 -p 22:22 -e GIT_USER_EMAIL=${GIT_USER_EMAIL} -e WANDB_API_KEY=${WANDB_API_KEY} -e PROJECT_REPO=${PROJECT_REPO} -e GITHUB_REPO=${GITHUB_REPO} -e HF_HUB_ENABLE_HF_TRANSFER=1 -e GITHUB_PAT=${GITHUB_PAT} -e HUGGING_FACE_HUB_TOKEN=${HUGGING_FACE_HUB_TOKEN} -e GIT_USER_NAME=${GIT_USER_NAME}" \
  --onstart-cmd "bash -lc 'if [ -f /usr/local/bin/start-project.sh ]; then /usr/local/bin/start-project.sh; else start-project.sh; fi'" \
  --search_params "external=false rentable=true verified=true"
```

## Verification

After adding Docker authentication:

1. Create a test instance from the template
2. Check that the Docker image pulls successfully
3. Verify the instance starts without authentication errors

## Notes

- The Docker Personal Access Token (PAT) is stored in the template
- The template will use these credentials to pull the private Docker image
- If the token expires, update it using one of the methods above
