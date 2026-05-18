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
# Gemma on Google AI Studio doesn't support audio input. When the cloud path
# is asked to transcribe audio we transparently use Gemini instead, which
# accepts audio/webm and audio/wav inline_data parts.
CLOUD_AUDIO_MODEL = os.getenv("CLOUD_AUDIO_MODEL", "gemini-2.0-flash")
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


async def audio_transcribe(audio_bytes: bytes, source_lang: str = "auto",
                            target_lang: str = "English") -> str:
    """ASR + translation.

    Routing:
      - If Ollama Gemma 4 E2B/E4B is up locally → use it.
      - Else if Google AI Studio is configured → use Gemini (gemini-2.0-flash,
        which natively accepts audio). This is the practical path on a
        cloud-only deployment, since Gemma 4 26B A4B (the cloud Gemma) has
        no audio modality.
      - Else raise.
    """
    prompt = build_audio_transcribe_prompt(source_lang, target_lang)

    if LOCAL_READY:
        audio_b64 = base64.b64encode(audio_bytes).decode()
        return await _call_local(
            "You are a multilingual speech transcription system.",
            prompt,
            audio_base64=audio_b64,
            prefer_audio_model=True,
        )

    if CLOUD_READY:
        return await _call_cloud_audio(
            "You are a multilingual speech transcription system.",
            prompt,
            audio_bytes=audio_bytes,
        )

    raise RuntimeError(
        "Audio requires either local Gemma 4 E2B/E4B (Ollama) or a configured "
        "GOOGLE_API_KEY for Gemini. Neither is available."
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

# Gemma models on the Google Generative Language API are stricter than Gemini
# about request shape. Notably, the `system_instruction` field is not
# universally supported on Gemma endpoints and can return 500 INTERNAL. The
# AI SDK provider gets around this by prepending the system message to the
# first user turn — that's the same workaround we use here.
_GEMMA_FAMILIES = ("gemma",)


def _is_gemma(model: str) -> bool:
    return any(model.lower().startswith(p) for p in _GEMMA_FAMILIES)


def _guess_image_mime(image_b64: str) -> str:
    """Sniff the first decoded bytes to pick the accurate MIME type.

    Sending mime_type=image/jpeg with a PNG body frequently returns
    500 INTERNAL from Google's API, so we sniff instead of hardcoding.
    """
    try:
        head = base64.b64decode(image_b64[:64], validate=False)[:12]
    except Exception:
        return "image/jpeg"
    if head.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if head.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if head[:6] in (b"GIF87a", b"GIF89a"):
        return "image/gif"
    if head[:4] == b"RIFF" and head[8:12] == b"WEBP":
        return "image/webp"
    if head[:4] == b"%PDF":
        return "application/pdf"
    return "image/jpeg"


def _guess_audio_mime(audio_bytes: bytes) -> str:
    """Sniff a few magic bytes to label the audio format for the API."""
    if len(audio_bytes) < 16:
        return "audio/webm"
    head = audio_bytes[:16]
    if head[:4] == b"OggS":
        return "audio/ogg"
    if head[:4] == b"RIFF" and head[8:12] == b"WAVE":
        return "audio/wav"
    if head[:4] in (b"\x1aE\xdf\xa3",):  # EBML / WebM
        return "audio/webm"
    if head[:3] == b"ID3" or (head[0] == 0xFF and (head[1] & 0xE0) == 0xE0):
        return "audio/mp3"
    return "audio/webm"


def _build_contents(
    system_prompt: str,
    user_prompt: str,
    model: str,
    image_base64: Optional[str] = None,
) -> tuple[Optional[Dict[str, Any]], list[Dict[str, Any]]]:
    """Build the (system_instruction, contents) pair, accounting for Gemma's
    quirks on Google's API.
    """
    parts: list[Dict[str, Any]] = []
    if image_base64:
        parts.append({
            "inline_data": {
                "mime_type": _guess_image_mime(image_base64),
                "data": image_base64,
            }
        })

    if _is_gemma(model):
        # Fold the system prompt into the first user message.
        combined = f"{system_prompt}\n\n---\n\n{user_prompt}" if system_prompt else user_prompt
        parts.append({"text": combined})
        return None, [{"role": "user", "parts": parts}]

    parts.append({"text": user_prompt})
    system_instruction = (
        {"parts": [{"text": system_prompt}]} if system_prompt else None
    )
    return system_instruction, [{"role": "user", "parts": parts}]


async def _call_cloud(
    system_prompt: str,
    user_prompt: str,
    enable_thinking: bool = False,
    image_base64: Optional[str] = None,
) -> str:
    """Call Google AI Studio's generateContent endpoint for text/vision."""
    if not GOOGLE_API_KEY:
        raise RuntimeError("GOOGLE_API_KEY not set")

    system_instruction, contents = _build_contents(
        system_prompt, user_prompt, CLOUD_MODEL, image_base64=image_base64,
    )

    payload: Dict[str, Any] = {
        "contents": contents,
        "generationConfig": {
            "temperature": 1.0,
            "topP": 0.95,
            "topK": 64,
            "maxOutputTokens": 8192,
        },
    }
    if system_instruction is not None:
        payload["system_instruction"] = system_instruction

    url = f"{GOOGLE_API_URL}/models/{CLOUD_MODEL}:generateContent?key={GOOGLE_API_KEY}"
    return await _post_generate(url, payload, label=f"Cloud {CLOUD_MODEL}")


async def _call_cloud_audio(
    system_prompt: str,
    user_prompt: str,
    audio_bytes: bytes,
) -> str:
    """Call Gemini for audio transcription/translation.

    Always uses CLOUD_AUDIO_MODEL (default gemini-2.0-flash) regardless of
    CLOUD_MODEL, because Gemma on Google AI Studio doesn't accept audio.
    """
    if not GOOGLE_API_KEY:
        raise RuntimeError("GOOGLE_API_KEY not set")

    audio_b64 = base64.b64encode(audio_bytes).decode()
    audio_mime = _guess_audio_mime(audio_bytes)

    parts = [
        {"inline_data": {"mime_type": audio_mime, "data": audio_b64}},
        {"text": user_prompt},
    ]
    payload: Dict[str, Any] = {
        "system_instruction": {"parts": [{"text": system_prompt}]},
        "contents": [{"role": "user", "parts": parts}],
        "generationConfig": {
            "temperature": 0.2,         # ASR wants deterministic output
            "topP": 0.95,
            "maxOutputTokens": 2048,
        },
    }

    url = (f"{GOOGLE_API_URL}/models/{CLOUD_AUDIO_MODEL}"
           f":generateContent?key={GOOGLE_API_KEY}")
    return await _post_generate(url, payload, label=f"Cloud audio {CLOUD_AUDIO_MODEL}")


async def _post_generate(url: str, payload: Dict[str, Any], label: str = "Cloud") -> str:
    """Single place that does the HTTP POST + response parsing + error reporting."""
    async with httpx.AsyncClient(timeout=120.0) as c:
        r = await c.post(url, json=payload)
        if r.status_code >= 400:
            # Surface the upstream message so the frontend doesn't just see
            # 'Internal error encountered.'
            try:
                body = r.json()
                upstream = (body.get("error", {}).get("message")
                            or body.get("error", {}).get("status")
                            or r.text)
            except Exception:
                upstream = r.text
            raise RuntimeError(f"{label} error {r.status_code}: {upstream}")
        data = r.json()

    candidates = data.get("candidates", [])
    if not candidates:
        # Sometimes Google returns 200 with promptFeedback.blockReason
        block = data.get("promptFeedback", {}).get("blockReason")
        if block:
            raise RuntimeError(f"{label} blocked: {block}")
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