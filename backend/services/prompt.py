"""Prompt builder for Gemma 4.

This is the heart of the system. It composes a single, structured prompt
from every piece of context the teacher has configured in the Flutter app:

  Profile         -> TEACHER section
  Curriculum      -> CURRICULUM CONTEXT (with codes like G5-MATH-LO-01)
  Prompt Editor   -> system message (role / instructions / constraints / style)
  Studio request  -> RESOURCE REQUEST
  Composition     -> OUTPUT FORMAT
  Question schemas -> JSON SCHEMA section (for structured output)
  Source text     -> SOURCE MATERIAL
  Web snippets    -> WEB CONTEXT

The output is two prompts: a system message and a user message, matching
Gemma 4's native system role support (a Gemma 4 advancement over Gemma 3).
"""

import json
from typing import Tuple

from models import GenerationRequest, CurriculumEntry


def build_system_prompt(req: GenerationRequest) -> str:
    """The system role — Prompt Editor settings + curriculum context."""
    t = req.prompt_template
    parts = [
        f"# ROLE\n{t.role}\n",
        f"# INSTRUCTIONS\n{t.instructions}\n",
        f"# CONSTRAINTS\n{t.constraints}\n",
        f"# STYLE\n{t.style}\n",
        f"# TEACHER PROFILE\n"
        f"Name: {req.profile.name} ({req.profile.designation})\n"
        f"School: {req.profile.school}\n",
    ]

    if req.curriculum_entry:
        parts.append(_curriculum_section(req.curriculum_entry, req.objective_codes))

    return "\n".join(parts)


def build_user_prompt(req: GenerationRequest) -> str:
    """The user turn — what to generate, in what form."""
    parts = []
    parts.append(_request_section(req))

    if req.source_text.strip():
        parts.append(
            f"# SOURCE MATERIAL (from teacher's upload)\n"
            f"Use this as factual grounding. Cite or paraphrase as needed.\n\n"
            f"{req.source_text[:8000]}\n"
        )

    if req.web_search_snippets:
        joined = "\n".join(f"- {s}" for s in req.web_search_snippets[:10])
        parts.append(
            f"# WEB CONTEXT (search: {req.web_search_query!r})\n{joined}\n"
        )

    parts.append(_output_format_section(req))
    return "\n".join(parts)


def build_prompts(req: GenerationRequest) -> Tuple[str, str]:
    """Return (system_prompt, user_prompt)."""
    return build_system_prompt(req), build_user_prompt(req)


# ── Sections ───────────────────────────────────────────────────────────────

def _curriculum_section(entry: CurriculumEntry, selected_objective_codes: list[str]) -> str:
    sel = set(selected_objective_codes or [])

    def fmt_items(items):
        return "\n".join(f"  [{i.code}] {i.text}" for i in items) or "  (none)"

    selected_outcomes = [o for o in entry.learning_outcomes.items
                         if not sel or o.code in sel] or entry.learning_outcomes.items

    out = [
        f"# CURRICULUM CONTEXT (NEP-aligned)",
        f"Grade: {entry.grade} | Subject: {entry.subject}",
    ]
    if entry.policy_scope:
        out.append(f"Policy scope: {entry.policy_scope}")
    if entry.domain.hasattr_text():
        out.append(f"Domain: {entry.domain.text or entry.domain.document_parsed_text or ''}")

    if entry.policy_document.text or entry.policy_document.document_parsed_text:
        pd = entry.policy_document.text or entry.policy_document.document_parsed_text
        out.append(f"\nPolicy excerpt:\n{pd[:1500]}")

    if entry.curricular_goals.items:
        out.append(f"\nCurricular Goals:\n{fmt_items(entry.curricular_goals.items)}")
    if entry.competencies.items:
        out.append(f"\nCompetencies:\n{fmt_items(entry.competencies.items)}")
    if selected_outcomes:
        out.append(f"\nLearning Outcomes (targeted by this resource):\n{fmt_items(selected_outcomes)}")
    if entry.lessons.items:
        out.append(f"\nLessons in this unit:\n{fmt_items(entry.lessons.items)}")
    if entry.additional_context.text or entry.additional_context.document_parsed_text:
        ac = entry.additional_context.text or entry.additional_context.document_parsed_text
        out.append(f"\nAdditional context:\n{ac[:1000]}")

    return "\n".join(out) + "\n"


# Monkey-patch helper used above (Pydantic v2 doesn't have hasattr-style helpers)
from models import FreeTextSection as _FTS
def _has_text(self) -> bool:
    return bool((self.text or "").strip() or (self.document_parsed_text or "").strip())
_FTS.hasattr_text = _has_text  # type: ignore[attr-defined]


def _request_section(req: GenerationRequest) -> str:
    comp = req.composition
    include = []
    if comp.include_questions: include.append("questions")
    if comp.include_answers: include.append("suggested answers")
    if comp.include_mark_scheme: include.append("mark scheme")
    if comp.include_rubric: include.append("rubric")
    if comp.include_workings: include.append("worked solutions")
    if comp.include_hints: include.append("hints")
    include_str = ", ".join(include) if include else "(default sections)"

    qtypes = ", ".join(req.question_types) if req.question_types else "any appropriate"
    objs = "\n".join(f"  - {o}" for o in req.objectives) if req.objectives else "  (none specified)"

    lang_line = req.languages[0] if req.language_mode == "monolingual" else \
        " then ".join(req.languages) if req.language_mode == "bilingual" else \
        ", ".join(req.languages)

    return (
        f"# RESOURCE REQUEST\n"
        f"Type: {req.resource_type}\n"
        f"Lesson: {req.lesson or '(unspecified)'}\n"
        f"Topic: {req.topic}\n"
        f"Language mode: {req.language_mode} ({lang_line})\n"
        f"Question types to use: {qtypes}\n"
        f"Sections to include: {include_str}\n"
        f"Learning objectives:\n{objs}\n"
        f"\nExtra instructions from teacher:\n{req.extra_instructions or '(none)'}\n"
    )


def _output_format_section(req: GenerationRequest) -> str:
    """Tell Gemma 4 to emit BOTH Markdown and JSON in a structured envelope."""
    schema_hint = _schema_hint(req)

    return f"""# OUTPUT FORMAT

Return your response in this EXACT structure with two fenced blocks:

```markdown
<the complete resource as printable Markdown>
- Use $...$ for inline math and $$...$$ for block math (LaTeX delimiters)
- Use proper Markdown headings (# H1, ## H2)
- For bilingual mode, write English fully, then a horizontal rule (---), then the second language
- For chemistry use $H_2O$, for physics $E = mc^2$, for math $\\frac{{1}}{{2}}$ etc.
```

```json
{schema_hint}
```

Both blocks are required. The JSON is for the app's structured renderer; the Markdown is for direct preview.
"""


def _schema_hint(req: GenerationRequest) -> str:
    """Build a JSON schema hint matching the resource type."""
    if req.resource_type in ("worksheet", "question_paper"):
        return json.dumps({
            "title": "string",
            "objectives": ["string"],
            "instructions": "string",
            "blocks": [
                {
                    "type": "questions",
                    "label": "Section A",
                    "columns": 1,
                    "questions": [
                        {
                            "type": "MCQ | Short Answer | True/False | Fill in the Blanks | ...",
                            "stem": "string (use LaTeX $...$ for math)",
                            "options": ["string", "..."],
                            "answer": "string",
                            "marks": 1
                        }
                    ]
                }
            ],
            "answer_key": [
                {"q_number": 1, "answer": "string", "explanation": "string", "marks": 1}
            ]
        }, indent=2)

    if req.resource_type in ("notes", "lesson_plan"):
        return json.dumps({
            "title": "string",
            "objectives": ["string"],
            "sections": [
                {
                    "heading": "string",
                    "body_markdown": "string (use $...$ for math)",
                    "key_points": ["string"]
                }
            ],
            "summary": "string"
        }, indent=2)

    if req.resource_type == "activity":
        return json.dumps({
            "title": "string",
            "objectives": ["string"],
            "materials": ["string"],
            "steps": [{"step": 1, "description": "string", "duration_minutes": 5}],
            "assessment": "string"
        }, indent=2)

    return json.dumps({"title": "string", "content": "string"}, indent=2)


# ── Multimodal helpers ─────────────────────────────────────────────────────

def build_image_extract_prompt(language_hint: str = "English") -> str:
    """For Gemma 4 vision: extract text from a curriculum/textbook image."""
    return (
        f"Extract all text from this image. Preserve structure: headings, bullet points, "
        f"tables, and equations. Use LaTeX delimiters $...$ for math. "
        f"The text may be in {language_hint}, Tamil, or Hindi. Output only the extracted text, no commentary."
    )


def build_audio_transcribe_prompt(source_lang: str = "Tamil", target_lang: str = "English") -> str:
    """For Gemma 4 E2B/E4B audio: ASR + translation."""
    if source_lang == target_lang:
        return (
            f"Transcribe the following speech segment in {source_lang} into {source_lang} text.\n\n"
            f"Follow these specific instructions for formatting the answer:\n"
            f"* Only output the transcription, with no newlines.\n"
            f"* When transcribing numbers, write the digits, i.e. write 1.7 and not one point seven, and write 3 instead of three."
        )
    return (
        f"Transcribe the following speech segment in {source_lang}, then translate it into {target_lang}.\n"
        f"When formatting the answer, first output the transcription in {source_lang}, then one newline, "
        f"then output the string '{target_lang}: ', then the translation in {target_lang}."
    )
