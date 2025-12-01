#!/bin/bash
set -e

echo "📁 Creating project files..."

# -------------------------------
# Create README.md
# -------------------------------
cat > README.md << 'EOF'
# Advance Deep Learning Setup

Reusable GPU-ready Docker image with PyTorch 2.8 + CUDA 12.8  
Pull from Docker Hub:

docker pull almamoha/advance-deeplearning:torch2.8-cuda12.8

EOF

# -------------------------------
# Create .gitignore
# -------------------------------
cat > .gitignore << 'EOF'
# Python artifacts
__pycache__/
*.pyc
*.pyo

# Virtual environments
.venv/
.venvs/

# Workspace
workspace/
EOF

# -------------------------------
# Create start-project.sh
# -------------------------------
cat > start-project.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

export HF_HUB_ENABLE_HF_TRANSFER="${HF_HUB_ENABLE_HF_TRANSFER:-1}"
export PIP_ROOT_USER_ACTION=ignore

apt-get update && apt-get install -y nano git curl && rm -rf /var/lib/apt/lists/*

if [ -n "${GIT_USER_NAME:-}" ]; then git config --global user.name "$GIT_USER_NAME"; fi
if [ -n "${GIT_USER_EMAIL:-}" ]; then git config --global user.email "$GIT_USER_EMAIL"; fi

cd /workspace

if [ -z "${PROJECT_REPO:-}" ]; then
  echo "PROJECT_REPO not set"
  exit 1
fi

PROJECT_DIR="${PROJECT_DIR:-$(basename "$PROJECT_REPO" .git)}"

if [ -n "${GITHUB_PAT:-}" ] && [[ "$PROJECT_REPO" == https://github.com/* ]]; then
  REPO_PATH="${PROJECT_REPO#https://github.com/}"
  AUTH_REPO_URL="https://${GITHUB_PAT}@github.com/${REPO_PATH}"
else
  AUTH_REPO_URL="$PROJECT_REPO"
fi

if [ -d "$PROJECT_DIR/.git" ]; then
  git -C "$PROJECT_DIR" pull --ff-only || true
else
  git clone "$AUTH_REPO_URL" "$PROJECT_DIR"
fi

if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
else
  export PATH="$HOME/.local/bin:$PATH"
fi

export UV_LINK_MODE=copy
export UV_PROJECT_ENVIRONMENT="/workspace/.venvs/$PROJECT_DIR"
mkdir -p /workspace/.venvs
rm -rf "/workspace/$PROJECT_DIR/.venv" || true

if [ ! -d "/workspace/.venvs/$PROJECT_DIR" ]; then
  uv venv "/workspace/.venvs/$PROJECT_DIR"
fi

. "/workspace/.venvs/$PROJECT_DIR/bin/activate"

cd "/workspace/$PROJECT_DIR"
if [ -f pyproject.toml ]; then
  uv sync
elif [ -f requirements.txt ]; then
  uv pip install -r requirements.txt
fi

uv pip install ipykernel

"/workspace/.venvs/$PROJECT_DIR/bin/python" -m ipykernel install \
  --user --name "$PROJECT_DIR" --display-name "$PROJECT_DIR (uv)" || true

if [ -n "${WANDB_API_KEY:-}" ]; then
  uv pip install wandb
  python -m wandb login "$WANDB_API_KEY" || true
fi

if ! command -v code-server >/dev/null 2>&1; then
  curl -fsSL https://code-server.dev/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

code-server --bind-addr 0.0.0.0:13337 --auth none \
  "/workspace/$PROJECT_DIR" >/tmp/code-server.log 2>&1 &

export JUPYTER_SERVER_ROOT="/workspace/$PROJECT_DIR"

exec /start.sh
EOF

chmod +x start-project.sh

# -------------------------------
# Create Dockerfile
# -------------------------------
cat > Dockerfile << 'EOF'
FROM runpod/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /workspace

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nano git curl \
    && rm -rf /var/lib/apt/lists/*

COPY start-project.sh /usr/local/bin/start-project.sh
RUN chmod +x /usr/local/bin/start-project.sh

EXPOSE 8888 6006 22 13337

CMD ["bash", "-lc", "start-project.sh"]
EOF

echo "✅ Files created successfully."

# -------------------------------
# Docker build
# -------------------------------
echo "🐳 Building Docker image..."
docker build -t advance-deeplearning-setup .

# -------------------------------
# Tag and push
# -------------------------------
TAG="torch2.8-cuda12.8"

echo "🏷️ Tagging image..."
docker tag advance-deeplearning-setup almamoha/advance-deeplearning:$TAG

echo "⬆️ Pushing to Docker Hub..."
docker push almamoha/advance-deeplearning:$TAG

echo "🎉 Done!"
echo "Image pushed: almamoha/advance-deeplearning:$TAG"