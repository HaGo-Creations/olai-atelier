"""Gemma Educator Agent — Backend.

Three-tier deployment:
  1. Cloud:   Google AI Studio API -> Gemma 4 26B A4B IT
  2. Local:   Ollama HTTP -> Gemma 4 E4B / E2B
  3. Mobile:  MediaPipe LLM Inference (handled in Flutter, not here)

Routes:
  /health           Status + which modes are available
  /parse            Upload PDF/image/audio -> text (uses Gemma 4 vision/audio)
  /generate         Build prompt from all settings -> Gemma 4 -> Markdown + JSON
  /export           Markdown + branding -> DOCX / PDF
  /download/{fn}    Serve exported files
  /resources        List saved resources (Cabinet sync)
  /resources/{id}   Get / update / delete a resource
"""

from dotenv import load_dotenv
load_dotenv()

import os
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse

from models import (
    GenerationRequest, GenerationResponse,
    ExportRequest, ExportResponse,
    ParseResponse, ResourceRecord, HealthResponse,
    UpdateResourceRequest,
)
from services import gemma, parser, exporter, store

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger("gemma_educator")


@asynccontextmanager
async def lifespan(app: FastAPI):
    log.info("Starting Gemma Educator Agent backend...")
    gemma.detect_availability()
    log.info(f"Local Gemma (Ollama) available: {gemma.LOCAL_READY}")
    log.info(f"Cloud Gemma (Google AI Studio) available: {gemma.CLOUD_READY}")
    yield
    log.info("Shutting down.")


app = FastAPI(
    title="Gemma Educator Agent API",
    description="Curriculum-aware classroom resource generation powered by Gemma 4.",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/", response_model=HealthResponse)
@app.get("/health", response_model=HealthResponse)
async def health():
    # Re-probe every health call so the frontend badge reflects Ollama
    # starting or stopping after the backend is already running.
    gemma.detect_availability()
    return HealthResponse(
        status="ok",
        local_available=gemma.LOCAL_READY,
        cloud_available=gemma.CLOUD_READY,
        local_model=os.getenv("OLLAMA_MODEL", "gemma4:4b"),
        cloud_model=os.getenv("CLOUD_MODEL", "gemma-4-26b-a4b-it"),
        version="1.0.0",
    )


@app.post("/parse", response_model=ParseResponse)
async def parse_file(
    file: UploadFile = File(...),
    use_gemma_vision: bool = Form(True),
    source_lang: str = Form("Tamil"),
    target_lang: str = Form("English"),
):
    content = await file.read()
    filename = file.filename or "upload"
    suffix = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""

    try:
        if suffix in {"png", "jpg", "jpeg", "webp", "bmp"}:
            text = await parser.parse_image(content, use_gemma_vision=use_gemma_vision)
            mode = "image"
        elif suffix in {"mp3", "wav", "m4a", "ogg", "webm"}:
            text = await parser.parse_audio(content, source_lang=source_lang, target_lang=target_lang)
            mode = "audio"
        elif suffix == "pdf":
            text = await parser.parse_pdf(content, use_gemma_vision=use_gemma_vision)
            mode = "pdf"
        elif suffix == "txt":
            text = content.decode("utf-8", errors="replace")
            mode = "text"
        else:
            raise HTTPException(400, f"Unsupported file type: .{suffix}")
    except HTTPException:
        raise
    except Exception as e:
        log.exception("parse failed")
        raise HTTPException(500, f"Parse failed: {e}")

    suggested_topic = None
    if text and len(text.strip()) > 30:
        first_line = text.strip().split("\n", 1)[0]
        suggested_topic = first_line[:80].strip() if first_line else None

    return ParseResponse(
        filename=filename, size_bytes=len(content), mode=mode,
        text=text, suggested_topic=suggested_topic,
    )


@app.post("/generate", response_model=GenerationResponse)
async def generate(req: GenerationRequest):
    try:
        result = await gemma.generate_resource(req)
        resource = store.save_resource(req, result)
        return GenerationResponse(
            resource_id=resource.id,
            content_markdown=result["markdown"],
            content_json=result.get("json"),
            model_used=result["model_used"],
            thinking_trace=result.get("thinking"),
            created_at=resource.created_at,
        )
    except Exception as e:
        log.exception("generate failed")
        raise HTTPException(500, f"Generation failed: {e}")


@app.post("/export", response_model=ExportResponse)
async def export(req: ExportRequest):
    try:
        path = await exporter.export_resource(req)
        filename = os.path.basename(path)
        return ExportResponse(
            path=path,
            download_url=f"/download/{filename}",
            format=req.format,
        )
    except Exception as e:
        log.exception("export failed")
        raise HTTPException(500, f"Export failed: {e}")


@app.get("/download/{filename}")
async def download(filename: str):
    path = os.path.join(exporter.EXPORT_DIR, filename)
    if not os.path.isfile(path):
        raise HTTPException(404, "File not found")
    return FileResponse(path, filename=filename)


# ── Resources (Cabinet sync) ───────────────────────────────────────────────

@app.get("/resources")
async def list_resources():
    return store.list_resources()


@app.get("/resources/{resource_id}", response_model=ResourceRecord)
async def get_resource(resource_id: str):
    r = store.get_resource(resource_id)
    if r is None:
        raise HTTPException(404, "Resource not found")
    return r


@app.put("/resources/{resource_id}", response_model=ResourceRecord)
async def update_resource(resource_id: str, req: UpdateResourceRequest):
    r = store.update_resource(resource_id, req)
    if r is None:
        raise HTTPException(404, "Resource not found")
    return r


@app.delete("/resources/{resource_id}")
async def delete_resource(resource_id: str):
    ok = store.delete_resource(resource_id)
    if not ok:
        raise HTTPException(404, "Resource not found")
    return {"deleted": True}


@app.post("/resources/{resource_id}/duplicate", response_model=ResourceRecord)
async def duplicate_resource(resource_id: str, new_title: str = Form(...)):
    r = store.duplicate_resource(resource_id, new_title)
    if r is None:
        raise HTTPException(404, "Resource not found")
    return r