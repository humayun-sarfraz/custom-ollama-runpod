#!/usr/bin/env bash
set -euo pipefail

echo "============================================"
echo "  Create Custom Ollama Model"
echo "============================================"
echo ""

# Load .env if present
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    source "$PROJECT_DIR/.env"
    set +a
fi

# Configuration
MODEL_NAME="${MODEL_NAME:-custom-assistant}"
MODEL_PATH="${MODEL_PATH:-/workspace/models/custom-model.gguf}"
MODELFILE="$PROJECT_DIR/Modelfile"

echo "Model Name: $MODEL_NAME"
echo "Model Path: $MODEL_PATH"
echo "Modelfile:  $MODELFILE"
echo ""

# ============================================
# CRITICAL CHECK: Model file must exist locally
# ============================================
if [ ! -f "$MODEL_PATH" ]; then
    echo "============================================"
    echo "  ERROR: Model file not found!"
    echo "============================================"
    echo ""
    echo "  Expected path: $MODEL_PATH"
    echo ""
    echo "  This project does NOT download models."
    echo "  You must manually place your GGUF model file at:"
    echo ""
    echo "    $MODEL_PATH"
    echo ""
    echo "  How to upload your model to RunPod:"
    echo "    1. Use RunPod file browser"
    echo "    2. Use scp: scp model.gguf root@<pod-ip>:$MODEL_PATH"
    echo "    3. Use runpodctl: runpodctl send model.gguf"
    echo "    4. Download directly on the pod from your own storage"
    echo ""
    echo "  Supported formats: .gguf"
    echo ""
    exit 1
fi

echo "Model file found: $MODEL_PATH"
FILE_SIZE=$(du -h "$MODEL_PATH" | cut -f1)
echo "File size: $FILE_SIZE"
echo ""

# Check Modelfile exists
if [ ! -f "$MODELFILE" ]; then
    echo "ERROR: Modelfile not found at $MODELFILE"
    exit 1
fi

# Check Ollama is running
echo "Checking Ollama server..."
if ! curl -s "http://localhost:11434/api/tags" &>/dev/null; then
    echo "ERROR: Ollama is not running."
    echo "  Start it first: ./scripts/start_ollama.sh"
    exit 1
fi
echo "Ollama is running."
echo ""

# Create a temporary Modelfile with the correct model path
TEMP_MODELFILE=$(mktemp)
trap "rm -f '$TEMP_MODELFILE'" EXIT
sed "s|^FROM .*|FROM $MODEL_PATH|" "$MODELFILE" > "$TEMP_MODELFILE"

echo "Creating model '$MODEL_NAME' from Modelfile..."
echo "  (This may take a moment depending on model size)"
echo ""

# Create the model — NO pull, NO download
timeout 600 ollama create "$MODEL_NAME" -f "$TEMP_MODELFILE" || {
    echo "ERROR: Model creation failed or timed out (10 min limit)."
    exit 1
}

echo ""
echo "============================================"
echo "  Model '$MODEL_NAME' created successfully!"
echo "============================================"
echo ""
echo "  Test it with:"
echo "    ollama run $MODEL_NAME \"Hello, who are you?\""
echo ""
echo "  Or via API:"
echo "    curl http://localhost:11434/api/generate \\"
echo "      -d '{\"model\": \"$MODEL_NAME\", \"prompt\": \"Hello!\", \"stream\": false}'"
echo ""
