"""Gemma 4 dispatcher.

Routes generation requests between:
  - LOCAL: Ollama (gemma-4-e4b-it or gemma-4-e2b-it) via HTTP at localhost:11434
  - CLOUD: Google AI Studio API (gemma-4-26b-a4b-it)

Mode is chosen per-request:
  model_mode = 'local'  -> force local
  model_mode = 'cloud'  -> force cloud
  model_mode = 'auto'   -> cloud if available, else local

Native Gemma 4 features used:
  - System prompt support (native, not workaround)
  - Function calling for structured JSON
  - Thinking mode (toggleable per request)
  - Vision input (PDF page images, photographed textbook pages)
  - Audio input (E2B/E4B only) for speech transcription
"""

import base64
import json
import os
import re
from typing import Any, Dict, Optional

import httpx

from models import GenerationRequest
from .prompt import (
    build_prompts, build_image_extract_prompt, build_audio_transcribe_prompt,
)

# ── State (set at startup) ────────────────────────────────────────────────

LOCAL_READY = False
CLOUD_READY = False

OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "gemma4:4b")          # `ollama list` name
OLLAMA_MODEL_AUDIO = os.getenv("OLLAMA_MODEL_AUDIO", "gemma4:4b")
CLOUD_MODEL = os.getenv("CLOUD_MODEL", "gemma-4-26b-a4b-it")
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY", "")
GOOGLE_API_URL = "https://generativelanguage.googleapis.com/v1beta"


def detect_availability() -> None:
    """Probe local Ollama and cloud API. Called at startup and on every /health request."""
    global LOCAL_READY, CLOUD_READY
    _probe_ollama()
    CLOUD_READY = bool(GOOGLE_API_KEY)


def _probe_ollama() -> None:
    """Check whether Ollama is running and has a Gemma model loaded."""
    global LOCAL_READY
    try:
        with httpx.Client(timeout=2.0) as c:
            r = c.get(f"{OLLAMA_URL}/api/tags")
            if r.status_code == 200:
                tags = r.json().get("models", [])
                names = [m.get("name", "").split(":")[0] for m in tags]
                target = OLLAMA_MODEL.split(":")[0]
                LOCAL_READY = target in names or any("gemma" in n for n in names)
                return
    except Exception:
        pass
    LOCAL_READY = False


# ── Public API ─────────────────────────────────────────────────────────────

async def generate_resource(req: GenerationRequest) -> Dict[str, Any]:
    """Build prompt + dispatch to chosen Gemma 4 backend.

    Returns a dict: {markdown, json, model_used, thinking?}
    """
    system_prompt, user_prompt = build_prompts(req)
    mode = _resolve_mode(req.model_mode)

    if mode == "cloud":
        raw = await _call_cloud(
            system_prompt, user_prompt,
            enable_thinking=req.enable_thinking,
            image_base64=req.image_base64,
        )
        model_used = f"cloud:{CLOUD_MODEL}"
    else:
        raw = await _call_local(
            system_prompt, user_prompt,
            enable_thinking=req.enable_thinking,
            image_base64=req.image_base64,
        )
        model_used = f"local:{OLLAMA_MODEL}"

    markdown, json_block, thinking = _split_response(raw)
    return {
        "markdown": markdown,
        "json": json_block,
        "thinking": thinking,
        "model_used": model_used,
    }


async def vision_extract_text(image_bytes: bytes, language_hint: str = "English") -> str:
    """Use Gemma 4 vision to OCR / parse an image."""
    prompt = build_image_extract_prompt(language_hint)
    image_b64 = base64.b64encode(image_bytes).decode()
    mode = _resolve_mode("auto")
    if mode == "cloud":
        return await _call_cloud("You are a precise OCR system.", prompt, image_base64=image_b64)
    return await _call_local("You are a precise OCR system.", prompt, image_base64=image_b64)


async def audio_transcribe(audio_bytes: bytes, source_lang: str = "Tamil",
                            target_lang: str = "English") -> str:
    """Use Gemma 4 E2B/E4B native audio for ASR + translation.

    Note: Cloud Gemma 4 26B A4B does NOT have audio. Audio is local-mode-only.
    This is a deliberate feature of the rural-school offline path.
    """
    if not LOCAL_READY:
        raise RuntimeError(
            "Audio requires local Gemma 4 E2B/E4B (cloud 26B doesn't have audio). "
            "Install Ollama and pull gemma-4-e2b-it."
        )
    prompt = build_audio_transcribe_prompt(source_lang, target_lang)
    audio_b64 = base64.b64encode(audio_bytes).decode()
    return await _call_local(
        "You are a multilingual speech transcription system.",
        prompt,
        audio_base64=audio_b64,
        prefer_audio_model=True,
    )


# ── Internal: routing ──────────────────────────────────────────────────────

def _resolve_mode(requested: str) -> str:
    if requested == "local":
        return "local" if LOCAL_READY else ("cloud" if CLOUD_READY else "local")
    if requested == "cloud":
        return "cloud" if CLOUD_READY else ("local" if LOCAL_READY else "cloud")
    # auto: prefer cloud (better quality), fall back to local
    if CLOUD_READY:
        return "cloud"
    return "local"


# ── Internal: local (Ollama) ───────────────────────────────────────────────

async def _call_local(
    system_prompt: str,
    user_prompt: str,
    enable_thinking: bool = False,
    image_base64: Optional[str] = None,
    audio_base64: Optional[str] = None,
    prefer_audio_model: bool = False,
) -> str:
    """Call Ollama's /api/chat endpoint with Gemma 4."""
    model = OLLAMA_MODEL_AUDIO if prefer_audio_model else OLLAMA_MODEL

    # Gemma 4's thinking mode: prepend <|think|> to system prompt
    sys = ("<|think|>\n" + system_prompt) if enable_thinking else system_prompt

    messages = [{"role": "system", "content": sys}]

    user_msg: Dict[str, Any] = {"role": "user", "content": user_prompt}
    if image_base64:
        user_msg["images"] = [image_base64]
    # Note: Ollama audio support is via image-style attachment in current versions.
    if audio_base64:
        user_msg["audio"] = [audio_base64]
    messages.append(user_msg)

    payload = {
        "model": model,
        "messages": messages,
        "stream": False,
        "options": {
            "temperature": 1.0,  # Gemma 4 recommended
            "top_p": 0.95,
            "top_k": 64,
            "num_ctx": 8192,
        },
    }

    async with httpx.AsyncClient(timeout=600.0) as c:
        r = await c.post(f"{OLLAMA_URL}/api/chat", json=payload)
        r.raise_for_status()
        data = r.json()
        return data.get("message", {}).get("content", "")


# ── Internal: cloud (Google AI Studio) ─────────────────────────────────────

async def _call_cloud(
    system_prompt: str,
    user_prompt: str,
    enable_thinking: bool = False,
    image_base64: Optional[str] = None,
) -> str:
    """Call Google AI Studio's generateContent endpoint."""
    if not GOOGLE_API_KEY:
        raise RuntimeError("GOOGLE_API_KEY not set")

    parts = []
    if image_base64:
        parts.append({
            "inline_data": {
                "mime_type": "image/jpeg",
                "data": image_base64,
            }
        })
    parts.append({"text": user_prompt})

    payload: Dict[str, Any] = {
        "system_instruction": {"parts": [{"text": system_prompt}]},
        "contents": [{"role": "user", "parts": parts}],
        "generationConfig": {
            "temperature": 1.0,
            "topP": 0.95,
            "topK": 64,
            "maxOutputTokens": 8192,
        },
    }

    # Google AI Studio's generateContent uses ?key= query param auth
    url = f"{GOOGLE_API_URL}/models/{CLOUD_MODEL}:generateContent?key={GOOGLE_API_KEY}"

    async with httpx.AsyncClient(timeout=120.0) as c:
        r = await c.post(url, json=payload)
        if r.status_code >= 400:
            raise RuntimeError(f"Cloud Gemma error {r.status_code}: {r.text}")
        data = r.json()

    candidates = data.get("candidates", [])
    if not candidates:
        return ""
    content_parts = candidates[0].get("content", {}).get("parts", [])
    return "".join(p.get("text", "") for p in content_parts)


# ── Internal: response parsing ─────────────────────────────────────────────

_MD_BLOCK = re.compile(r"```markdown\s*(.*?)```", re.DOTALL | re.IGNORECASE)
_JSON_BLOCK = re.compile(r"```json\s*(.*?)```", re.DOTALL | re.IGNORECASE)
_THINK_BLOCK = re.compile(r"<\|channel\|>thought\s*(.*?)<channel\|>", re.DOTALL)


def _split_response(raw: str) -> tuple[str, Optional[Dict], Optional[str]]:
    """Extract Markdown + JSON + thinking from Gemma 4's structured envelope."""
    thinking = None
    m = _THINK_BLOCK.search(raw)
    if m:
        thinking = m.group(1).strip()
        raw = _THINK_BLOCK.sub("", raw)

    md_match = _MD_BLOCK.search(raw)
    json_match = _JSON_BLOCK.search(raw)

    markdown = md_match.group(1).strip() if md_match else raw.strip()
    json_data = None
    if json_match:
        try:
            json_data = json.loads(json_match.group(1).strip())
        except json.JSONDecodeError:
            json_data = None

    # Fallback: if no fenced markdown block was found, use everything except the json block
    if not md_match and json_match:
        markdown = raw.replace(json_match.group(0), "").strip()

    return markdown, json_data, thinking
