#!/usr/bin/env bash
set -euo pipefail

echo "============================================"
echo "  GPU Verification Script"
echo "============================================"
echo ""

# Check nvidia-smi
echo "[1/4] Checking nvidia-smi..."
if ! command -v nvidia-smi &>/dev/null; then
    echo "ERROR: nvidia-smi not found."
    echo "  - Make sure NVIDIA drivers are installed."
    echo "  - On RunPod, this should be pre-installed."
    exit 1
fi
echo "  nvidia-smi found."
echo ""

# Show GPU info
echo "[2/4] GPU Information:"
nvidia-smi --query-gpu=name,memory.total,driver_version,compute_cap --format=csv,noheader
echo ""

# Check CUDA runtime
echo "[3/4] Checking CUDA runtime..."
if command -v nvcc &>/dev/null; then
    echo "  CUDA compiler (nvcc) found: $(nvcc --version | grep release | awk '{print $6}')"
elif [ -d "/usr/local/cuda" ]; then
    echo "  CUDA directory found at /usr/local/cuda"
elif command -v nvidia-smi &>/dev/null; then
    CUDA_VER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1)
    echo "  NVIDIA driver version: $CUDA_VER"
    echo "  CUDA runtime libraries should be available via the driver."
else
    echo "WARNING: CUDA runtime not explicitly found, but GPU may still work with Ollama."
fi
echo ""

# Check Docker NVIDIA runtime (optional)
echo "[4/4] Checking Docker NVIDIA runtime (optional)..."
if command -v docker &>/dev/null; then
    if docker info 2>/dev/null | grep -qi nvidia; then
        echo "  Docker NVIDIA runtime is available."
    else
        echo "  Docker is installed but NVIDIA runtime not detected."
        echo "  Install nvidia-container-toolkit if using Docker with GPU."
    fi
else
    echo "  Docker not installed (optional, not required)."
fi

echo ""
echo "============================================"
echo "  GPU verification complete."
echo "============================================"
