#!/usr/bin/env bash
# scripts/dev_local.sh
# One-command local development startup for Linux / macOS.
# Starts the backend against a local Ollama instance.
# The Flutter frontend must be started separately (see step 4).

set -e
cd "$(dirname "$0")/.."

echo ""
echo "╔═══════════════════════════════════════════════════╗"
echo "║       Gemma Educator Agent — Local Dev            ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""

# ── 1. Check Ollama ────────────────────────────────────────────────────────
echo "[1/4] Checking Ollama..."
if ! command -v ollama &>/dev/null; then
    echo "  ERROR: Ollama not found."
    echo "  Install it from https://ollama.com then re-run this script."
    exit 1
fi
echo "  Ollama found."

# ── 2. Check / create backend env ─────────────────────────────────────────
echo "[2/4] Checking backend/.env..."
if [ ! -f "backend/.env" ]; then
    if [ -f "backend/.env.example" ]; then
        cp "backend/.env.example" "backend/.env"
        echo "  Created backend/.env from template."
        echo "  IMPORTANT: Edit backend/.env and set OLLAMA_MODEL to match 'ollama list'."
        echo "  Press Enter after editing to continue..."
        ${EDITOR:-nano} "backend/.env"
        read -r
    else
        echo "  WARNING: backend/.env.example not found. Create backend/.env manually."
    fi
else
    echo "  backend/.env already exists."
fi

# ── 3. Read OLLAMA_MODEL from env file ────────────────────────────────────
OLLAMA_MODEL=$(grep -E '^OLLAMA_MODEL=' backend/.env 2>/dev/null | cut -d= -f2 || echo "gemma4:4b")
echo "[3/4] Using Ollama model: ${OLLAMA_MODEL}"
echo "  Checking if model is available..."
if ! ollama list | grep -qi "${OLLAMA_MODEL%%:*}"; then
    echo "  Model not found locally. Pulling ${OLLAMA_MODEL}..."
    echo "  This may take several minutes on first run."
    ollama pull "${OLLAMA_MODEL}"
fi
echo "  Model ready."

# ── 4. Start backend ───────────────────────────────────────────────────────
echo "[4/4] Starting backend on http://localhost:7860 ..."
echo ""
echo "─────────────────────────────────────────────────────"
echo " Next step: open a NEW terminal and run:"
echo ""
echo "   cd frontend"
echo "   flutter run -d web-server --web-port 8080"
echo ""
echo " Then open http://localhost:8080 in your browser."
echo "─────────────────────────────────────────────────────"
echo ""

cd backend
pip install -r requirements.txt -q
uvicorn main:app --reload --port 7860
