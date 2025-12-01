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
