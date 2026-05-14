"""
FastAPI wrapper for local Ollama API.
Does NOT use OpenAI API. Does NOT require any external model provider.
Calls the local Ollama instance at http://localhost:11434.
"""

import logging
import os
from contextlib import asynccontextmanager

import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field

load_dotenv()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
DEFAULT_MODEL = os.getenv("MODEL_NAME", "custom-assistant")
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "*").split(",")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Check Ollama connectivity on startup."""
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.get(f"{OLLAMA_BASE_URL}/api/tags", timeout=5)
            resp.raise_for_status()
            logger.info(f"Connected to Ollama at {OLLAMA_BASE_URL}")
    except Exception as e:
        logger.warning(f"Cannot reach Ollama at {OLLAMA_BASE_URL}: {e}")
        logger.warning("Make sure Ollama is running: ./scripts/start_ollama.sh")
    yield


app = FastAPI(
    title="Custom Ollama API Wrapper",
    description="Lightweight API wrapper around a local Ollama instance. No external model providers.",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
    max_age=3600,
)


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=8000)
    model: str = Field(DEFAULT_MODEL, max_length=100)
    stream: bool = False


class ChatResponse(BaseModel):
    response: str
    model: str


@app.get("/health")
async def health():
    """Health check — verifies Ollama is reachable."""
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.get(f"{OLLAMA_BASE_URL}/api/tags", timeout=5)
            resp.raise_for_status()
            return {"status": "healthy", "ollama": OLLAMA_BASE_URL}
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Ollama unreachable: {e}")


@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """Send a message to the local Ollama model."""
    payload = {
        "model": request.model,
        "prompt": request.message,
        "stream": False,
    }

    try:
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{OLLAMA_BASE_URL}/api/generate",
                json=payload,
                timeout=120,
            )
            resp.raise_for_status()
            data = resp.json()
    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="Ollama request timed out")
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Ollama error: {e}")

    return ChatResponse(
        response=data.get("response", ""),
        model=data.get("model", request.model),
    )


@app.get("/", response_class=HTMLResponse)
async def index():
    """Minimal chat UI."""
    return """
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Ollama Chat</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #0f172a; color: #e2e8f0; min-height: 100vh; display: flex; flex-direction: column; }
  .header { padding: 1rem 2rem; background: #1e293b; border-bottom: 1px solid #334155; }
  .header h1 { font-size: 1.25rem; color: #38bdf8; }
  .header p { font-size: 0.8rem; color: #94a3b8; margin-top: 0.25rem; }
  .config { padding: 0.75rem 2rem; background: #1e293b; display: flex; gap: 1rem; flex-wrap: wrap; border-bottom: 1px solid #334155; }
  .config label { font-size: 0.8rem; color: #94a3b8; }
  .config input { background: #0f172a; border: 1px solid #334155; color: #e2e8f0; padding: 0.4rem 0.6rem; border-radius: 6px; font-size: 0.85rem; }
  .chat { flex: 1; overflow-y: auto; padding: 2rem; display: flex; flex-direction: column; gap: 1rem; }
  .msg { max-width: 75%; padding: 0.75rem 1rem; border-radius: 12px; line-height: 1.5; font-size: 0.95rem; white-space: pre-wrap; }
  .msg.user { background: #1d4ed8; align-self: flex-end; border-bottom-right-radius: 4px; }
  .msg.bot { background: #1e293b; align-self: flex-start; border-bottom-left-radius: 4px; border: 1px solid #334155; }
  .input-bar { padding: 1rem 2rem; background: #1e293b; display: flex; gap: 0.75rem; border-top: 1px solid #334155; }
  .input-bar input { flex: 1; background: #0f172a; border: 1px solid #334155; color: #e2e8f0; padding: 0.75rem 1rem; border-radius: 8px; font-size: 1rem; outline: none; }
  .input-bar input:focus { border-color: #38bdf8; }
  .input-bar button { background: #2563eb; color: white; border: none; padding: 0.75rem 1.5rem; border-radius: 8px; cursor: pointer; font-size: 1rem; font-weight: 600; }
  .input-bar button:hover { background: #1d4ed8; }
  .input-bar button:disabled { background: #334155; cursor: not-allowed; }
</style>
</head>
<body>
  <div class="header">
    <h1>Ollama Chat</h1>
    <p>Local model &mdash; no data leaves this server</p>
  </div>
  <div class="config">
    <div><label>Model</label><br><input id="model" value="custom-assistant"></div>
    <div><label>Backend URL</label><br><input id="backend" value="" size="30"></div>
  </div>
  <div class="chat" id="chat"></div>
  <div class="input-bar">
    <input id="input" placeholder="Type a message..." autofocus>
    <button id="send" onclick="sendMsg()">Send</button>
  </div>
<script>
  const backendInput = document.getElementById('backend');
  backendInput.value = window.location.origin;

  document.getElementById('input').addEventListener('keydown', e => {
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendMsg(); }
  });

  async function sendMsg() {
    const input = document.getElementById('input');
    const msg = input.value.trim();
    if (!msg) return;
    input.value = '';

    const chat = document.getElementById('chat');
    chat.innerHTML += '<div class="msg user">' + escapeHtml(msg) + '</div>';
    chat.scrollTop = chat.scrollHeight;

    const btn = document.getElementById('send');
    btn.disabled = true;
    btn.textContent = '...';

    try {
      const base = backendInput.value.replace(/\\/$/, '');
      const model = document.getElementById('model').value;
      const res = await fetch(base + '/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: msg, model, stream: false })
      });
      const data = await res.json();
      const reply = data.response || data.detail || 'No response';
      chat.innerHTML += '<div class="msg bot">' + escapeHtml(reply) + '</div>';
    } catch (e) {
      chat.innerHTML += '<div class="msg bot" style="color:#f87171">Error: ' + escapeHtml(e.message) + '</div>';
    }
    btn.disabled = false;
    btn.textContent = 'Send';
    chat.scrollTop = chat.scrollHeight;
  }

  function escapeHtml(t) {
    const d = document.createElement('div');
    d.textContent = t;
    return d.innerHTML;
  }
</script>
</body>
</html>
"""
