---
title: Gemma Educator
emoji: 🎓
colorFrom: blue
colorTo: indigo
sdk: docker
app_port: 7860
pinned: false
---

# Gemma Educator Agent — Backend

FastAPI backend that powers the Gemma Educator Agent. Supports three deployment modes:

| Mode | Where it runs | AI model |
|------|--------------|----------|
| **Cloud** | Hugging Face Space | Google AI Studio — Gemma 4 26B |
| **Local** | Your machine (Docker or native) | Ollama — Gemma 4 4B/12B |
| **Hybrid** | Local backend, both models | Tries cloud first, falls back to local |

---

## Hugging Face Space (cloud deployment)

The Dockerfile is already set up for HF Spaces. You only need to add one secret.

**Steps:**
1. Push the `backend/` folder to a Hugging Face Space (Docker SDK).
2. In the Space settings → **Secrets**, add:
   - `GOOGLE_API_KEY` — your Google AI Studio key ([get one free](https://aistudio.google.com/app/apikey))
3. The Space will build automatically. Check the logs tab for startup messages.
4. Your Space URL (e.g. `https://hago-creations-gemma-educator.hf.space`) is what goes in the frontend's env file as `API_BASE_URL`.

**Optional HF secrets** (only needed if you want to change defaults):
```
CLOUD_MODEL=gemma-4-26b-a4b-it
EXPORT_DIR=/tmp/gemma_exports
```

> Ollama cannot run on Hugging Face's free CPU tier. Cloud mode only on HF.

---

## Local development — Docker Compose (recommended)

Runs the backend + Ollama together. Flutter frontend still runs natively.

```bash
# 1. Copy and fill in the env file
cp backend/.env.example backend/.env
# Edit backend/.env — set OLLAMA_MODEL to match your installed model

# 2. Start the stack (first run pulls the Gemma 4 model — allow ~5 min)
docker compose up

# 3. Backend is now live at http://localhost:7860
#    Update your frontend env file: API_BASE_URL=http://localhost:7860

# 4. Run the Flutter frontend
cd frontend
flutter run -d web-server --web-port 8080
```

To stop: `docker compose down`

---

## Local development — Native (no Docker)

Best for GPU inference or if you already have Ollama installed.

### Step 1 — Install and start Ollama

Download from [ollama.com](https://ollama.com) (available for Windows, Mac, Linux).

```bash
# Pull the Gemma 4 model (choose based on your RAM/VRAM)
ollama pull gemma4:4b     # ~3 GB,  works on CPU
ollama pull gemma4:12b    # ~8 GB,  needs 8 GB VRAM
ollama pull gemma4:27b    # ~16 GB, needs 16 GB VRAM

# Verify it's running
ollama list
```

### Step 2 — Start the backend

```bash
cd backend

# Create your env file
cp .env.example .env
# Edit .env: set OLLAMA_MODEL to match `ollama list` output
#            set GOOGLE_API_KEY if you also want cloud mode

pip install -r requirements.txt
uvicorn main:app --reload --port 7860
```

### Step 3 — Configure frontend

Set `API_BASE_URL=http://localhost:7860` in your frontend env file, then:

```bash
cd frontend
flutter run -d web-server --web-port 8080
```

Open `http://localhost:8080` in your browser.

---

## API reference

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Backend status + which AI modes are available |
| `/generate` | POST | Generate educational resource (Markdown + JSON) |
| `/parse` | POST | Parse uploaded PDF / image / audio to text |
| `/export` | POST | Convert resource to DOCX or PDF |
| `/download/{filename}` | GET | Serve exported file |
| `/resources` | GET | List saved resources |
| `/resources/{id}` | PUT / DELETE | Update or delete a resource |

Health response shows live model availability:
```json
{
  "status": "ok",
  "local_available": true,
  "cloud_available": true,
  "local_model": "gemma4:4b",
  "cloud_model": "gemma-4-26b-a4b-it"
}
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `local_available: false` | Run `ollama list` — model name in `.env` must match exactly |
| `cloud_available: false` | Check `GOOGLE_API_KEY` is set and valid |
| Export 404 | `EXPORT_DIR` not writable — set to a path with write permission |
| CORS error from frontend | Backend CORS is `*` — check `API_BASE_URL` has no trailing slash |
| Ollama model not found | Run `ollama pull gemma4:4b` and restart the backend |
