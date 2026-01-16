# Build for amd64 architecture (required for Vast.ai)
# Note: Platform is specified at build time via --platform flag
FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /workspace

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nano git curl build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install PyTorch for amd64 (CPU version, or use CUDA version if needed)
RUN pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

COPY start-project.sh /usr/local/bin/start-project.sh
RUN chmod +x /usr/local/bin/start-project.sh

# Create entrypoint script that clones GitHub repository
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8888 6006 22 13337

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash", "-lc", "start-project.sh"]
