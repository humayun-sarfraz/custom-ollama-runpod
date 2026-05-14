<p align="center">
  <img src="https://ollama.com/public/ollama.png" alt="Ollama" width="80">
</p>

<h1 align="center">Custom Ollama Model on RunPod GPU</h1>

<p align="center">
  <strong>Run your own GGUF model on a RunPod GPU instance using Ollama</strong><br>
  FastAPI wrapper &bull; Web Chat UI &bull; Docker support &bull; Zero model downloads
</p>

<p align="center">
  <a href="#quick-start"><img src="https://img.shields.io/badge/Quick_Start-blue?style=for-the-badge" alt="Quick Start"></a>
  <a href="#api-usage"><img src="https://img.shields.io/badge/API_Docs-green?style=for-the-badge" alt="API Docs"></a>
  <a href="#docker-usage"><img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker"></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/python-3.10+-3776AB?logo=python&logoColor=white" alt="Python">
  <img src="https://img.shields.io/badge/FastAPI-009688?logo=fastapi&logoColor=white" alt="FastAPI">
  <img src="https://img.shields.io/badge/Ollama-000000?logo=ollama&logoColor=white" alt="Ollama">
  <img src="https://img.shields.io/badge/NVIDIA-GPU-76B900?logo=nvidia&logoColor=white" alt="NVIDIA GPU">
  <img src="https://img.shields.io/badge/RunPod-Ready-7B2D8B" alt="RunPod">
  <img src="https://img.shields.io/badge/License-MIT-yellow" alt="License">
</p>

---

> **This project does NOT download any model weights.**
> No `ollama pull`, no `wget`, no `curl` downloads, no `huggingface-cli download`.
> You must manually place your GGUF model file on the server.

---

## Table of Contents

- [Features](#features)
- [What This Project Does NOT Do](#what-this-project-does-not-do)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [API Usage](#api-usage)
- [Web Chat UI](#web-chat-ui)
- [RunPod Port Exposure](#runpod-port-exposure)
- [Docker Usage](#docker-usage)
- [Project Structure](#project-structure)
- [Environment Variables](#environment-variables)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## Features

| Feature | Description |
|---------|-------------|
| **No Auto Downloads** | Never downloads model weights — you provide the GGUF file |
| **GPU Accelerated** | Full NVIDIA GPU support via Ollama |
| **FastAPI Wrapper** | Clean REST API with `/health` and `/chat` endpoints |
| **Web Chat UI** | Built-in browser-based chat interface |
| **Docker Ready** | Dockerfile + Compose with NVIDIA runtime |
| **RunPod Optimized** | Pre-configured for RunPod GPU instances |
| **Configurable** | All paths, ports, and model settings via `.env` |
| **Robust Scripts** | Bash scripts with strict mode, validation, and cleanup |

---

## What This Project Does NOT Do

- Does **not** download any LLM model weights
- Does **not** run `ollama pull`
- Does **not** fetch models from HuggingFace, URLs, or any remote source
- Does **not** bake model weights into any Docker image

---

## Architecture

```
                    +------------------+
                    |   Your Browser   |
                    |   (Chat UI)      |
                    +--------+---------+
                             |
                        Port 8000
                             |
                    +--------+---------+
                    |   FastAPI        |
                    |   Wrapper        |
                    |   /health /chat  |
                    +--------+---------+
                             |
                      localhost:11434
                             |
                    +--------+---------+
                    |   Ollama Server  |
                    |   (GPU Runtime)  |
                    +--------+---------+
                             |
                    +--------+---------+
                    |   Your GGUF      |
                    |   Model File     |
                    +------------------+
```

---

## Quick Start

### 1. Set Up RunPod

1. Create a RunPod GPU pod (recommended: RTX 3090, A40, A100, or similar)
2. Choose an Ubuntu-based template
3. SSH into your pod or use the web terminal

### 2. Upload Your GGUF Model

Place your model file at `/workspace/models/custom-model.gguf`.

```bash
# SCP from your local machine
scp my-model.gguf root@<pod-ip>:/workspace/models/custom-model.gguf

# Or use runpodctl
runpodctl send my-model.gguf
```

> **If the model file does not exist at the expected path, model creation will stop with an error.**

### 3. Clone and Set Up

```bash
cd /workspace
git clone https://github.com/humayun-sarfraz/custom-ollama-runpod.git
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
MODEL_PATH=/workspace/models/custom-model.gguf \
MODEL_NAME=custom-assistant \
./scripts/create_model.sh
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

**Start the wrapper:**
```bash
cd api
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

**Health check:**
```bash
curl http://localhost:8000/health
```

**Chat:**
```bash
curl http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "custom-assistant",
    "message": "Hello",
    "stream": false
  }'
```

**Response format:**
```json
{
  "response": "Hello! How can I help you today?",
  "model": "custom-assistant"
}
```

---

## Web Chat UI

Open `http://localhost:8000` in your browser for the built-in chat interface.

**Features:**
- Real-time message display
- Configurable model name
- Configurable backend URL
- Dark theme
- Keyboard shortcut (Enter to send)

---

## RunPod Port Exposure

To access your APIs externally on RunPod:

1. Go to your pod settings
2. Add **port 11434** (Ollama API) and **port 8000** (FastAPI) as HTTP ports
3. Your endpoints become:

| Service | URL |
|---------|-----|
| Ollama API | `https://<pod-id>-11434.proxy.runpod.net` |
| FastAPI + Chat UI | `https://<pod-id>-8000.proxy.runpod.net` |

---

## Docker Usage

### Build and Run with Docker Compose

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

### Docker Features

- NVIDIA GPU runtime with CUDA 12.4
- Health check on `/health` endpoint
- Auto-restarts on failure
- Model directory mounted as volume (no weights in image)

---

## Project Structure

```
custom-ollama-runpod/
├── README.md                  # This file
├── .env.example               # Environment variable template
├── .gitignore                 # Git ignore rules
├── Modelfile                  # Ollama model definition (local GGUF only)
├── docker-compose.yml         # Docker Compose with GPU + healthcheck
├── LICENSE                    # MIT License
│
├── scripts/
│   ├── verify_gpu.sh          # Verify GPU / CUDA / drivers
│   ├── start_ollama.sh        # Start Ollama server (0.0.0.0:11434)
│   ├── create_model.sh        # Create model from local GGUF file
│   └── test_model.sh          # Test model via CLI and API
│
├── api/
│   ├── main.py                # FastAPI wrapper + embedded chat UI
│   └── requirements.txt       # Python dependencies
│
└── docker/
    ├── Dockerfile             # Multi-service container (Ollama + FastAPI)
    └── entrypoint.sh          # Container entrypoint with signal handling
```

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MODEL_NAME` | `custom-assistant` | Name for your Ollama model |
| `MODEL_PATH` | `/workspace/models/custom-model.gguf` | Path to your GGUF file |
| `OLLAMA_HOST` | `0.0.0.0:11434` | Ollama server bind address |
| `OLLAMA_BASE_URL` | `http://localhost:11434` | Ollama API URL (used by FastAPI) |
| `API_PORT` | `8000` | FastAPI wrapper port |
| `ALLOWED_ORIGINS` | `*` | CORS allowed origins (comma-separated) |

---

## Troubleshooting

<details>
<summary><strong>"Model file not found"</strong></summary>

Your GGUF file is not at the expected path. Place it at the path specified in `MODEL_PATH`.

```bash
ls -la /workspace/models/
```
</details>

<details>
<summary><strong>"Ollama is not running"</strong></summary>

Start Ollama first, then create the model:
```bash
./scripts/start_ollama.sh
```
</details>

<details>
<summary><strong>GPU not detected</strong></summary>

- Run `./scripts/verify_gpu.sh` to diagnose
- Ensure your RunPod pod has a GPU allocated
- For Docker: install `nvidia-container-toolkit` and use `--gpus all`
</details>

<details>
<summary><strong>Ollama install fails</strong></summary>

- Ensure you have internet access for the Ollama runtime installer
- The installer only installs the Ollama binary, NOT any model
</details>

<details>
<summary><strong>Model creation fails</strong></summary>

- Check that the GGUF file is valid and not corrupted
- Ensure enough disk space for model registration
- Check Ollama logs: `journalctl -u ollama`
</details>

<details>
<summary><strong>FastAPI wrapper can't reach Ollama</strong></summary>

- Verify Ollama is running: `curl http://localhost:11434/api/tags`
- Check `OLLAMA_BASE_URL` in your `.env`
</details>

<details>
<summary><strong>Port not accessible on RunPod</strong></summary>

- Add the port (11434 or 8000) in RunPod pod settings as an HTTP port
- Use the proxy URL: `https://<pod-id>-<port>.proxy.runpod.net`
</details>

---

## Important Warnings

| | Warning |
|---|---------|
| **No Weights** | This project does not provide model weights. You must supply your own GGUF file. |
| **No Downloads** | No script downloads any model. If `MODEL_PATH` does not exist, creation stops. |
| **Your Responsibility** | Do not add automatic model downloads to any script in this project. |

---

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

<p align="center">
  Made with care for the self-hosted AI community
</p>
