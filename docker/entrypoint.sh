#!/usr/bin/env bash
set -euo pipefail

echo "============================================"
echo "  Custom Ollama on RunPod — Docker Entry"
echo "============================================"
echo ""

# ============================================
# CRITICAL: Do NOT download any model weights
# ============================================

MODEL_NAME="${MODEL_NAME:-custom-assistant}"
MODEL_PATH="${MODEL_PATH:-/workspace/models/custom-model.gguf}"
API_PORT="${API_PORT:-8000}"
OLLAMA_PID=""
FASTAPI_PID=""
TEMP_MODELFILE=""

# Unified cleanup handler
cleanup() {
    echo "Shutting down services..."
    [ -n "$TEMP_MODELFILE" ] && rm -f "$TEMP_MODELFILE"
    [ -n "$FASTAPI_PID" ] && kill "$FASTAPI_PID" 2>/dev/null || true
    [ -n "$OLLAMA_PID" ] && kill "$OLLAMA_PID" 2>/dev/null || true
    wait 2>/dev/null
}
trap cleanup EXIT INT TERM

# Check for model file
if [ ! -f "$MODEL_PATH" ]; then
    echo "============================================"
    echo "  WARNING: Model file not found!"
    echo "============================================"
    echo ""
    echo "  Expected: $MODEL_PATH"
    echo ""
    echo "  Mount your model directory:"
    echo "    docker run -v /path/to/models:/workspace/models ..."
    echo ""
    echo "  This container does NOT download models."
    echo "  You must provide the GGUF file yourself."
    echo ""
    echo "  Starting Ollama server without a model..."
    echo "  You can still create a model later."
    echo ""
fi

# Start Ollama in background
echo "Starting Ollama server..."
ollama serve &
OLLAMA_PID=$!

# Wait for Ollama with timeout
for i in $(seq 1 30); do
    if curl -s --max-time 2 http://localhost:11434/api/tags &>/dev/null; then
        break
    fi
    sleep 1
done

if ! curl -s --max-time 2 http://localhost:11434/api/tags &>/dev/null; then
    echo "ERROR: Ollama failed to start within 30 seconds."
    exit 1
fi
echo "Ollama is running."

# Create model if file exists
if [ -f "$MODEL_PATH" ]; then
    echo "Creating model '$MODEL_NAME' from $MODEL_PATH..."
    TEMP_MODELFILE=$(mktemp)
    sed "s|^FROM .*|FROM $MODEL_PATH|" /app/Modelfile > "$TEMP_MODELFILE"
    timeout 600 ollama create "$MODEL_NAME" -f "$TEMP_MODELFILE" || {
        echo "ERROR: Model creation failed or timed out."
        exit 1
    }
    rm -f "$TEMP_MODELFILE"
    TEMP_MODELFILE=""
    echo "Model '$MODEL_NAME' created."
fi

# Start FastAPI wrapper
echo "Starting FastAPI wrapper on port $API_PORT..."
/app/venv/bin/uvicorn main:app --host 0.0.0.0 --port "$API_PORT" &
FASTAPI_PID=$!

echo ""
echo "============================================"
echo "  Services running:"
echo "    Ollama:  http://localhost:11434"
echo "    FastAPI: http://localhost:$API_PORT"
echo "============================================"

# Wait for any process to exit, then propagate exit code
wait -n "$OLLAMA_PID" "$FASTAPI_PID"
EXIT_CODE=$?
echo "A service exited with code $EXIT_CODE"
exit "$EXIT_CODE"
