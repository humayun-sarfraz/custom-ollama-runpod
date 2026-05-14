#!/usr/bin/env bash
set -euo pipefail

echo "============================================"
echo "  Test Custom Ollama Model"
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

MODEL_NAME="${MODEL_NAME:-custom-assistant}"

# Check Ollama is running
echo "[1/4] Checking Ollama server..."
if ! curl -s "http://localhost:11434/api/tags" &>/dev/null; then
    echo "ERROR: Ollama is not running."
    echo "  Start it first: ./scripts/start_ollama.sh"
    exit 1
fi
echo "  Ollama is running."
echo ""

# Check model exists
echo "[2/4] Checking model '$MODEL_NAME' exists..."
MODELS=$(curl -s "http://localhost:11434/api/tags")
if echo "$MODELS" | grep -q "\"$MODEL_NAME\""; then
    echo "  Model '$MODEL_NAME' found."
else
    echo "  Available models:"
    echo "$MODELS" | python3 -m json.tool 2>/dev/null || echo "$MODELS"
    echo ""
    echo "WARNING: Model '$MODEL_NAME' may not exist."
    echo "  Create it first: ./scripts/create_model.sh"
    echo "  Continuing anyway..."
fi
echo ""

# Test with ollama run
echo "[3/4] Testing with 'ollama run'..."
echo "  Prompt: Say hello in one sentence."
echo "  Response:"
echo "  ---"
ollama run "$MODEL_NAME" "Say hello in one sentence." 2>&1 || {
    echo "ERROR: ollama run failed."
    exit 1
}
echo "  ---"
echo ""

# Test with API
echo "[4/4] Testing with Ollama API..."
echo "  Sending POST to http://localhost:11434/api/generate"
echo ""

RESPONSE=$(curl -s http://localhost:11434/api/generate \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"$MODEL_NAME\",
        \"prompt\": \"Explain what you are in one sentence.\",
        \"stream\": false
    }")

if [ -z "$RESPONSE" ]; then
    echo "ERROR: No response from API."
    exit 1
fi

echo "  API Response:"
echo "  ---"
echo "$RESPONSE" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r.get('response','No response field'))" 2>/dev/null || echo "$RESPONSE"
echo "  ---"

echo ""
echo "============================================"
echo "  All tests passed!"
echo "============================================"
