"""Parse uploaded files into text.

Strategy:
  - PDF: try pypdf first (fast). If text is sparse, render pages to images
    and ask Gemma 4 vision (handles scanned PDFs with multilingual handwriting).
  - Image: Gemma 4 vision directly (OCR, charts, handwriting, all languages).
  - Audio: Gemma 4 E2B/E4B native ASR + translation.
"""

import io
from typing import List

from . import gemma


async def parse_pdf(content: bytes, use_gemma_vision: bool = True) -> str:
    """Extract text from a PDF; use Gemma 4 vision for image-only pages."""
    try:
        from pypdf import PdfReader
    except ImportError:
        raise RuntimeError("pypdf not installed. Run: pip install pypdf")

    reader = PdfReader(io.BytesIO(content))
    pages_text: List[str] = []
    needs_vision_pages: List[int] = []

    for i, page in enumerate(reader.pages):
        try:
            t = page.extract_text() or ""
        except Exception:
            t = ""
        if len(t.strip()) < 50:
            needs_vision_pages.append(i)
            pages_text.append("")  # placeholder
        else:
            pages_text.append(t.strip())

    # Vision fallback for sparse-text pages
    if use_gemma_vision and needs_vision_pages and gemma.LOCAL_READY or gemma.CLOUD_READY:
        try:
            import pypdfium2 as pdfium  # pip install pypdfium2
            pdf = pdfium.PdfDocument(content)
            for idx in needs_vision_pages:
                if idx >= len(pdf):
                    continue
                page = pdf[idx]
                pil = page.render(scale=2).to_pil()
                buf = io.BytesIO()
                pil.save(buf, format="PNG")
                vision_text = await gemma.vision_extract_text(buf.getvalue())
                pages_text[idx] = vision_text.strip()
        except ImportError:
            # pypdfium2 not installed — skip vision fallback gracefully
            pass
        except Exception as e:
            # Vision parsing failed for some pages — leave them blank
            print(f"[parser] vision fallback failed: {e}")

    return "\n\n".join(p for p in pages_text if p)


async def parse_image(content: bytes, use_gemma_vision: bool = True) -> str:
    """Gemma 4 vision handles OCR, handwriting, charts, all languages."""
    if not use_gemma_vision:
        # Fallback: tesseract (rare path — only if user explicitly disables Gemma)
        try:
            from PIL import Image
            import pytesseract
            img = Image.open(io.BytesIO(content))
            return pytesseract.image_to_string(img, lang="eng+tam+hin")
        except ImportError:
            raise RuntimeError(
                "Image parsing requires Gemma 4 vision (preferred) or pytesseract (fallback)."
            )

    if not (gemma.LOCAL_READY or gemma.CLOUD_READY):
        raise RuntimeError("No Gemma 4 backend available for image parsing.")

    return await gemma.vision_extract_text(content)


async def parse_audio(
    content: bytes,
    source_lang: str = "Tamil",
    target_lang: str = "English",
) -> str:
    """Gemma 4 E2B/E4B native ASR — local mode only (cloud 26B has no audio)."""
    if not gemma.LOCAL_READY:
        raise RuntimeError(
            "Audio requires local Gemma 4 E2B/E4B (Ollama). "
            "Cloud Gemma 4 26B does not support audio input. "
            "Install Ollama and pull gemma-4-e2b-it for audio."
        )
    return await gemma.audio_transcribe(content, source_lang=source_lang, target_lang=target_lang)
