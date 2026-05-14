# Custom Ollama Model on RunPod GPU

Run your own GGUF model on a RunPod GPU instance using Ollama — with a FastAPI wrapper and web chat UI.

> **This project does NOT download any model weights.**
> No `ollama pull`, no `wget`, no `curl` downloads, no `huggingface-cli download`.
> You must manually place your GGUF model file on the server.

---

## What This Project Does

- Installs and configures the Ollama runtime on a RunPod GPU instance
- Creates a custom Ollama model from **your local GGUF file**
- Exposes the Ollama API on port 11434
- Provides a FastAPI wrapper on port 8000 with `/health` and `/chat` endpoints
- Includes a minimal web chat UI at `http://localhost:8000`
- Supports Docker with NVIDIA GPU runtime

## What This Project Does NOT Do

- Does **not** download any LLM model weights
- Does **not** run `ollama pull`
- Does **not** fetch models from HuggingFace, URLs, or any remote source
- Does **not** bake model weights into any Docker image

---

## Quick Start

### 1. Set Up RunPod

1. Create a RunPod GPU pod (recommended: RTX 3090, A40, A100, or similar)
2. Choose an Ubuntu-based template
3. SSH into your pod or use the web terminal

### 2. Upload Your GGUF Model

Place your model file at `/workspace/models/custom-model.gguf`.

Methods to upload:
```bash
# SCP from your local machine
scp my-model.gguf root@<pod-ip>:/workspace/models/custom-model.gguf

# Or use runpodctl
runpodctl send my-model.gguf

# Or download from your own storage (not from a public model repo)
# The point is: YOU provide the model file
```

> **If the model file does not exist at the expected path, model creation will stop with an error.**

### 3. Clone and Set Up

```bash
cd /workspace
git clone <this-repo> custom-ollama-runpod
cd custom-ollama-runpod

cp .env.example .env
# Edit .env if needed (model name, path, ports)

chmod +x scripts/*.sh
```

### 4. Verify GPU

```bash
./scripts/verify_gpu.sh
```

### 5. Install and Start Ollama

```bash
# Install Ollama (runtime only, no models)
curl -fsSL https://ollama.com/install.sh | sh

# Start Ollama server
./scripts/start_ollama.sh
```

### 6. Create Your Custom Model

```bash
MODEL_PATH=/workspace/models/custom-model.gguf MODEL_NAME=custom-assistant ./scripts/create_model.sh
```

### 7. Test the Model

```bash
./scripts/test_model.sh
```

---

## API Usage

### Ollama API (port 11434)

```bash
curl http://localhost:11434/api/generate \
  -d '{
    "model": "custom-assistant",
    "prompt": "Explain what you are in one sentence.",
    "stream": false
  }'
```

### FastAPI Wrapper (port 8000)

Start the wrapper:
```bash
cd api
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

Call the API:
```bash
# Health check
curl http://localhost:8000/health

# Chat
curl http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "custom-assistant",
    "message": "Hello",
    "stream": false
  }'
```

### Web Chat UI

Open `http://localhost:8000` in your browser for the built-in chat interface.

---

## RunPod Port Exposure

To access your APIs externally on RunPod:

1. Go to your pod settings
2. Add **port 11434** (Ollama API) and **port 8000** (FastAPI) as HTTP ports
3. Your endpoints become:
   - `https://<pod-id>-11434.proxy.runpod.net`
   - `https://<pod-id>-8000.proxy.runpod.net`

---

## Docker Usage

### Build and Run

```bash
# Make sure your model is at /workspace/models/custom-model.gguf
docker compose up --build -d
```

### Manual Docker Run

```bash
docker build -t custom-ollama -f docker/Dockerfile .

docker run --gpus all \
  -p 11434:11434 \
  -p 8000:8000 \
  -v /workspace/models:/workspace/models \
  -e MODEL_NAME=custom-assistant \
  -e MODEL_PATH=/workspace/models/custom-model.gguf \
  custom-ollama
```

---

## Project Structure

```
custom-ollama-runpod/
├── README.md
├── .env.example
├── Modelfile                  # Ollama model definition (local GGUF only)
├── docker-compose.yml
├── scripts/
│   ├── start_ollama.sh        # Start Ollama server
│   ├── create_model.sh        # Create model from local GGUF
│   ├── test_model.sh          # Test model via CLI and API
│   └── verify_gpu.sh          # Verify GPU availability
├── api/
│   ├── main.py                # FastAPI wrapper + web chat UI
│   └── requirements.txt
└── docker/
    ├── Dockerfile
    └── entrypoint.sh
```

---

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `MODEL_NAME` | `custom-assistant` | Name for your Ollama model |
| `MODEL_PATH` | `/workspace/models/custom-model.gguf` | Path to your GGUF file |
| `OLLAMA_HOST` | `0.0.0.0:11434` | Ollama bind address |
| `OLLAMA_BASE_URL` | `http://localhost:11434` | Ollama API URL (for FastAPI) |
| `API_PORT` | `8000` | FastAPI wrapper port |

---

## Troubleshooting

### "Model file not found"
Your GGUF file is not at the expected path. Place it at the path specified in `MODEL_PATH`.

### "Ollama is not running"
Run `./scripts/start_ollama.sh` first, then create the model.

### GPU not detected
- Run `./scripts/verify_gpu.sh` to diagnose
- Ensure your RunPod pod has a GPU allocated
- For Docker: install `nvidia-container-toolkit` and use `--gpus all`

### Ollama install fails
- Ensure you have internet access for the Ollama runtime installer
- The installer only installs the Ollama binary, NOT any model

### Model creation fails
- Check that the GGUF file is valid and not corrupted
- Ensure enough disk space for model registration
- Check Ollama logs: `journalctl -u ollama` or check terminal output

### FastAPI wrapper can't reach Ollama
- Verify Ollama is running: `curl http://localhost:11434/api/tags`
- Check `OLLAMA_BASE_URL` in your `.env`

### Port not accessible on RunPod
- Add the port (11434 or 8000) in RunPod pod settings as an HTTP port
- Use the proxy URL: `https://<pod-id>-<port>.proxy.runpod.net`

---

## Warnings

- **This project does not provide model weights.** You must supply your own GGUF file.
- **If `MODEL_PATH` does not exist, model creation will stop.** No fallback download.
- **Do not add automatic model downloads** to any script in this project.
- All scripts validate that the model file exists before proceeding.
