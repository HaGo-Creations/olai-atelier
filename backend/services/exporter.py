"""Export resources to DOCX and PDF with Brand & Layout applied.

DOCX:  python-docx (headers, footers, logo, typography)
PDF:   reportlab (programmatic layout with branding)

Both formats apply:
  - Logo + school name + address in header (alignable)
  - Footer text or phone/email
  - Heading + Body typography from Brand & Layout
  - Per-document header/footer override from Studio Output
"""

import io
import os
import re
import uuid
from typing import Optional

from models import ExportRequest, Branding, PageLayout, HeaderFooterOverride

EXPORT_DIR = os.getenv("EXPORT_DIR", "/tmp/gemma_exports")
os.makedirs(EXPORT_DIR, exist_ok=True)


async def export_resource(req: ExportRequest) -> str:
    """Export to DOCX or PDF, return file path."""
    safe_title = re.sub(r"[^\w\s-]", "", req.title).strip().replace(" ", "_") or "resource"
    short_id = uuid.uuid4().hex[:8]

    if req.format == "docx":
        path = os.path.join(EXPORT_DIR, f"{safe_title}_{short_id}.docx")
        _export_docx(req, path)
    elif req.format == "pdf":
        path = os.path.join(EXPORT_DIR, f"{safe_title}_{short_id}.pdf")
        _export_pdf(req, path)
    else:
        raise ValueError(f"Unsupported format: {req.format}. Use docx or pdf.")

    return path


# ── DOCX ───────────────────────────────────────────────────────────────────

def _export_docx(req: ExportRequest, path: str) -> None:
    from docx import Document
    from docx.shared import Pt, Mm, RGBColor
    from docx.enum.text import WD_ALIGN_PARAGRAPH

    doc = Document()
    branding = req.branding
    layout = (branding.layouts.get("docx") if branding else None) or PageLayout()
    override = req.header_footer_override

    # Page setup
    section = doc.sections[0]
    section.top_margin = Mm(layout.margin_top)
    section.bottom_margin = Mm(layout.margin_bottom)
    section.left_margin = Mm(layout.margin_left)
    section.right_margin = Mm(layout.margin_right)

    # Header
    if branding and branding.apply_on_export and override.include_header:
        _add_docx_header(section, branding, layout)

    # Footer
    if branding and branding.apply_on_export and override.include_footer:
        _add_docx_footer(section, branding, layout)

    # Body — parse Markdown into paragraphs
    _add_docx_body(doc, req.content_markdown, layout)

    doc.save(path)


def _add_docx_header(section, branding: Branding, layout: PageLayout):
    from docx.enum.text import WD_ALIGN_PARAGRAPH
    from docx.shared import Pt

    header = section.header
    p = header.paragraphs[0]
    align_map = {"left": WD_ALIGN_PARAGRAPH.LEFT,
                 "center": WD_ALIGN_PARAGRAPH.CENTER,
                 "right": WD_ALIGN_PARAGRAPH.RIGHT}
    p.alignment = align_map.get(layout.logo_position, WD_ALIGN_PARAGRAPH.LEFT)

    runs_text = []
    if branding.school_name:
        runs_text.append(("SCHOOL", branding.school_name))
    if branding.address:
        runs_text.append(("ADDRESS", branding.address))

    for kind, text in runs_text:
        run = p.add_run(text + "\n")
        run.bold = (kind == "SCHOOL")
        run.font.size = Pt(layout.heading_size * 0.55) if kind == "SCHOOL" else Pt(layout.body_size * 0.8)


def _add_docx_footer(section, branding: Branding, layout: PageLayout):
    from docx.enum.text import WD_ALIGN_PARAGRAPH
    from docx.shared import Pt

    footer = section.footer
    p = footer.paragraphs[0]
    align_map = {"left": WD_ALIGN_PARAGRAPH.LEFT,
                 "center": WD_ALIGN_PARAGRAPH.CENTER,
                 "right": WD_ALIGN_PARAGRAPH.RIGHT}
    p.alignment = align_map.get(layout.footer_alignment, WD_ALIGN_PARAGRAPH.CENTER)

    text = branding.footer_text or " ".join(filter(None, [branding.phone, branding.email]))
    run = p.add_run(text)
    run.font.size = Pt(max(8, layout.body_size * 0.75))


def _add_docx_body(doc, markdown: str, layout):
    from docx.shared import Pt

    style = doc.styles["Normal"]
    style.font.size = Pt(layout.body_size)

    for raw_line in markdown.split("\n"):
        line = raw_line.rstrip()
        if not line:
            doc.add_paragraph("")
            continue
        if line.startswith("# "):
            p = doc.add_paragraph()
            run = p.add_run(line[2:])
            run.bold = True
            run.font.size = Pt(layout.heading_size)
        elif line.startswith("## "):
            p = doc.add_paragraph()
            run = p.add_run(line[3:])
            run.bold = True
            run.font.size = Pt(layout.heading_size * 0.85)
        elif line.startswith("### "):
            p = doc.add_paragraph()
            run = p.add_run(line[4:])
            run.bold = True
            run.font.size = Pt(layout.heading_size * 0.75)
        elif line.startswith("- ") or line.startswith("* "):
            doc.add_paragraph(line[2:], style="List Bullet")
        elif re.match(r"^\d+\.\s", line):
            doc.add_paragraph(re.sub(r"^\d+\.\s", "", line), style="List Number")
        elif line == "---":
            doc.add_paragraph("─" * 40)
        else:
            doc.add_paragraph(line)


# ── PDF ────────────────────────────────────────────────────────────────────

def _export_pdf(req: ExportRequest, path: str):
    from reportlab.lib.pagesizes import A4, LETTER
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import mm
    from reportlab.lib.enums import TA_LEFT, TA_CENTER, TA_RIGHT
    from reportlab.platypus import (
        SimpleDocTemplate, Paragraph, Spacer, PageBreak, HRFlowable,
    )

    branding = req.branding
    layout = (branding.layouts.get("pdf") if branding else None) or PageLayout()
    override = req.header_footer_override

    page_size = A4 if layout.page_size == "a4" else LETTER

    doc = SimpleDocTemplate(
        path, pagesize=page_size,
        topMargin=layout.margin_top * mm,
        bottomMargin=layout.margin_bottom * mm,
        leftMargin=layout.margin_left * mm,
        rightMargin=layout.margin_right * mm,
        title=req.title,
    )

    styles = getSampleStyleSheet()
    h_style = ParagraphStyle(
        "H", parent=styles["Heading1"],
        fontSize=layout.heading_size,
        leading=layout.heading_size * 1.3,
    )
    h2_style = ParagraphStyle(
        "H2", parent=styles["Heading2"],
        fontSize=layout.heading_size * 0.85,
    )
    body_style = ParagraphStyle(
        "Body", parent=styles["BodyText"],
        fontSize=layout.body_size,
        leading=layout.body_size * layout.line_spacing,
    )

    flowables = []

    for raw_line in req.content_markdown.split("\n"):
        line = raw_line.rstrip()
        if not line:
            flowables.append(Spacer(1, layout.body_size))
            continue
        if line.startswith("# "):
            flowables.append(Paragraph(_html_escape(line[2:]), h_style))
        elif line.startswith("## "):
            flowables.append(Paragraph(_html_escape(line[3:]), h2_style))
        elif line == "---":
            flowables.append(HRFlowable(width="100%"))
        else:
            flowables.append(Paragraph(_html_escape(line), body_style))

    def _on_page(canvas, doc_):
        if branding and branding.apply_on_export and override.include_header:
            _draw_pdf_header(canvas, doc_, branding, layout)
        if branding and branding.apply_on_export and override.include_footer:
            _draw_pdf_footer(canvas, doc_, branding, layout)

    doc.build(flowables, onFirstPage=_on_page, onLaterPages=_on_page)


def _draw_pdf_header(canvas, doc_, branding: Branding, layout: PageLayout):
    from reportlab.lib.units import mm
    canvas.saveState()
    y = doc_.pagesize[1] - 12 * mm
    if layout.logo_position == "left":
        x = 20 * mm
    elif layout.logo_position == "right":
        x = doc_.pagesize[0] - 20 * mm
    else:
        x = doc_.pagesize[0] / 2

    if branding.school_name:
        canvas.setFont("Helvetica-Bold", layout.heading_size * 0.55)
        if layout.logo_position == "right":
            canvas.drawRightString(x, y, branding.school_name)
        elif layout.logo_position == "center":
            canvas.drawCentredString(x, y, branding.school_name)
        else:
            canvas.drawString(x, y, branding.school_name)
    if branding.address:
        canvas.setFont("Helvetica", layout.body_size * 0.7)
        if layout.logo_position == "right":
            canvas.drawRightString(x, y - 10, branding.address)
        elif layout.logo_position == "center":
            canvas.drawCentredString(x, y - 10, branding.address)
        else:
            canvas.drawString(x, y - 10, branding.address)
    canvas.restoreState()


def _draw_pdf_footer(canvas, doc_, branding: Branding, layout: PageLayout):
    from reportlab.lib.units import mm
    canvas.saveState()
    canvas.setFont("Helvetica", layout.body_size * 0.7)
    text = branding.footer_text or " ".join(filter(None, [branding.phone, branding.email]))
    if not text:
        canvas.restoreState()
        return
    y = 10 * mm
    if layout.footer_alignment == "left":
        canvas.drawString(20 * mm, y, text)
    elif layout.footer_alignment == "right":
        canvas.drawRightString(doc_.pagesize[0] - 20 * mm, y, text)
    else:
        canvas.drawCentredString(doc_.pagesize[0] / 2, y, text)
    canvas.restoreState()


def _html_escape(s: str) -> str:
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
