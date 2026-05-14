# ============================================
# Custom Ollama on RunPod GPU — Dockerfile
# ============================================
# WARNING: This Dockerfile does NOT download any model weights.
# WARNING: No "ollama pull" is ever executed.
# WARNING: You must mount your GGUF model file via volume.
# ============================================

FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV OLLAMA_HOST=0.0.0.0:11434
ENV MODEL_NAME=custom-assistant
ENV MODEL_PATH=/workspace/models/custom-model.gguf
ENV OLLAMA_BASE_URL=http://localhost:11434
ENV API_PORT=8000

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama runtime ONLY (no models)
RUN curl -fsSL https://ollama.com/install.sh | sh

# Set up Python virtual environment
WORKDIR /app
RUN python3 -m venv /app/venv
COPY api/requirements.txt /app/requirements.txt
RUN /app/venv/bin/pip install --no-cache-dir -r requirements.txt

COPY api/main.py /app/main.py
COPY Modelfile /app/Modelfile
COPY scripts/ /app/scripts/
RUN chmod +x /app/scripts/*.sh

# Copy entrypoint
COPY docker/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Expose ports
EXPOSE 11434
EXPOSE 8000

# NOTE: Model weights are NOT included in this image.
# Mount your model directory:
#   -v /path/to/models:/workspace/models
VOLUME ["/workspace/models"]

ENTRYPOINT ["/app/entrypoint.sh"]
