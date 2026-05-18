"""Pydantic schemas for Gemma Educator Agent.

These mirror the Flutter models in lib/models/models.dart so JSON payloads
serialize/deserialize cleanly between frontend and backend.
"""

from datetime import datetime
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field


# ── Shared/atomic ──────────────────────────────────────────────────────────

class CurriculumItem(BaseModel):
    id: str
    code: str
    text: str


class ListSection(BaseModel):
    items: List[CurriculumItem] = []
    document_name: Optional[str] = None
    document_parsed_text: Optional[str] = None


class FreeTextSection(BaseModel):
    text: str = ""
    document_name: Optional[str] = None
    document_parsed_text: Optional[str] = None


class CurriculumEntry(BaseModel):
    id: str
    grade: str
    subject: str
    policy_scope: Optional[str] = None
    policy_document: FreeTextSection = FreeTextSection()
    domain: FreeTextSection = FreeTextSection()
    additional_context: FreeTextSection = FreeTextSection()
    curricular_goals: ListSection = ListSection()
    competencies: ListSection = ListSection()
    learning_outcomes: ListSection = ListSection()
    lessons: ListSection = ListSection()


class TeacherProfile(BaseModel):
    name: str = ""
    designation: str = ""
    school: str = ""
    subjects: List[str] = []
    grades: List[str] = []


class PromptTemplate(BaseModel):
    name: str = "Default"
    role: str = "You are an experienced school teacher creating classroom resources."
    instructions: str = "Use only curriculum vocabulary. Do not introduce concepts beyond the lesson scope."
    constraints: str = "Stay aligned with NEP 2020 framework. Use grade-appropriate language."
    style: str = "Clear, structured, with section headings. Suitable for printing."


class QSchemaField(BaseModel):
    id: str
    label: str
    kind: str  # stem | options | answer | binary | blanks | matchPairs | numeric | diagram | custom
    required: bool = True
    option_count: int = 4
    allow_more_options: bool = False


class QuestionSchema(BaseModel):
    id: str
    name: str
    fields: List[QSchemaField]


class OutputComposition(BaseModel):
    mode: str = "both"  # questionsOnly | answersOnly | both
    include_questions: bool = True
    include_answers: bool = True
    include_mark_scheme: bool = True
    include_rubric: bool = False
    include_workings: bool = False
    include_hints: bool = False
    separate_answer_key: bool = False


class PageLayout(BaseModel):
    page_size: str = "a4"
    margin_top: float = 20
    margin_bottom: float = 20
    margin_left: float = 20
    margin_right: float = 20
    heading_size: float = 18
    heading_weight: int = 700
    body_size: float = 11
    body_weight: int = 400
    line_spacing: float = 1.15
    logo_position: str = "left"
    footer_alignment: str = "center"
    slide_aspect: str = "ar16_9"
    pdf_mode: str = "document"


class Branding(BaseModel):
    logo_path: Optional[str] = None
    logo_base64: Optional[str] = None  # for cloud uploads
    school_name: str = ""
    address: str = ""
    phone: str = ""
    email: str = ""
    footer_text: str = ""
    apply_on_export: bool = True
    layouts: Dict[str, PageLayout] = Field(default_factory=lambda: {
        "docx": PageLayout(),
        "pdf": PageLayout(),
        "pptx": PageLayout(),
    })


class HeaderFooterOverride(BaseModel):
    include_header: bool = True
    include_footer: bool = True


# ── Request / Response ─────────────────────────────────────────────────────

class GenerationRequest(BaseModel):
    """Everything Gemma 4 needs to know — assembled by Flutter providers."""
    resource_type: str  # worksheet | lesson_plan | question_paper | presentation | activity | notes
    subject: str
    grade: str
    lesson: str = ""
    topic: str
    objectives: List[str] = []  # objective text strings (already chosen from chips)
    objective_codes: List[str] = []  # the matching codes for traceability
    language_mode: str = "monolingual"  # mono | bilingual | multilingual
    languages: List[str] = ["English"]
    extra_instructions: str = ""
    source_text: str = ""  # from parsed uploads
    web_search_query: str = ""
    web_search_snippets: List[str] = []
    composition: OutputComposition = OutputComposition()
    question_schemas: List[QuestionSchema] = []
    question_types: List[str] = []  # selected types names

    profile: TeacherProfile = TeacherProfile()
    curriculum_entry: Optional[CurriculumEntry] = None
    prompt_template: PromptTemplate = PromptTemplate()

    model_mode: str = "auto"  # local | cloud | auto
    enable_thinking: bool = False  # Gemma 4 reasoning toggle

    # Multimodal hints
    image_base64: Optional[str] = None  # if user attached an image for Gemma 4 vision


class GenerationResponse(BaseModel):
    resource_id: str
    content_markdown: str
    content_json: Optional[Dict[str, Any]] = None
    model_used: str
    thinking_trace: Optional[str] = None
    created_at: datetime


class ParseResponse(BaseModel):
    filename: str
    size_bytes: int
    mode: str  # pdf | image | audio | text
    text: str
    suggested_topic: Optional[str] = None


class ExportRequest(BaseModel):
    resource_id: Optional[str] = None
    title: str
    content_markdown: str
    format: str  # docx | pdf
    branding: Optional[Branding] = None
    header_footer_override: HeaderFooterOverride = HeaderFooterOverride()


class ExportResponse(BaseModel):
    path: str
    download_url: str
    format: str


class ResourceRecord(BaseModel):
    id: str
    title: str
    type: str
    subject: str
    grade: str
    lesson: str = ""
    content: str
    content_json: Optional[Dict[str, Any]] = None
    created_at: datetime
    updated_at: datetime
    model_used: str = "local"
    source_upload_ids: List[str] = []


class UpdateResourceRequest(BaseModel):
    title: Optional[str] = None
    content: Optional[str] = None


class HealthResponse(BaseModel):
    status: str
    local_available: bool
    cloud_available: bool
    local_model: str
    cloud_model: str
    version: str