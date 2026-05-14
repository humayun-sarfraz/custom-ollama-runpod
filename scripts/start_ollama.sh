#!/usr/bin/env bash
set -euo pipefail

echo "============================================"
echo "  Starting Ollama Server"
echo "============================================"
echo ""

# Load .env if present
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
if [ -f "$PROJECT_DIR/.env" ]; then
    echo "Loading .env file..."
    set -a
    source "$PROJECT_DIR/.env"
    set +a
fi

# Set defaults
OLLAMA_HOST="${OLLAMA_HOST:-0.0.0.0:11434}"
export OLLAMA_HOST

# Check if Ollama is installed
if ! command -v ollama &>/dev/null; then
    echo "ERROR: Ollama is not installed."
    echo ""
    echo "Install Ollama by running:"
    echo "  curl -fsSL https://ollama.com/install.sh | sh"
    echo ""
    echo "NOTE: This only installs the Ollama runtime."
    echo "      It does NOT download any model weights."
    exit 1
fi

echo "Ollama version: $(ollama --version 2>/dev/null || echo 'unknown')"
echo ""

# Check if Ollama is already running
if curl -s "http://localhost:11434/api/tags" &>/dev/null; then
    echo "Ollama is already running."
    echo ""
    echo "  Local API:  http://localhost:11434"
    echo "  Bind addr:  $OLLAMA_HOST"
    echo ""
    echo "To expose on RunPod, add port 11434 in your pod settings."
    exit 0
fi

echo "Starting Ollama server..."
echo "  Binding to: $OLLAMA_HOST"
echo ""

# Start Ollama in the background
ollama serve &
OLLAMA_PID=$!

# Wait for Ollama to be ready
echo "Waiting for Ollama to start..."
for i in $(seq 1 30); do
    if curl -s "http://localhost:11434/api/tags" &>/dev/null; then
        echo ""
        echo "============================================"
        echo "  Ollama is running!"
        echo "============================================"
        echo ""
        echo "  Local API:  http://localhost:11434"
        echo "  Bind addr:  $OLLAMA_HOST"
        echo "  PID:        $OLLAMA_PID"
        echo ""
        echo "  RunPod port exposure:"
        echo "    Add port 11434 (HTTP) in your RunPod pod settings"
        echo "    Your API will be available at:"
        echo "    https://<pod-id>-11434.proxy.runpod.net"
        echo ""
        echo "  To stop: kill $OLLAMA_PID"
        exit 0
    fi
    sleep 1
    printf "."
done

echo ""
echo "ERROR: Ollama failed to start within 30 seconds."
echo "  Check logs or try running 'ollama serve' manually."
kill "$OLLAMA_PID" 2>/dev/null || true
exit 1
