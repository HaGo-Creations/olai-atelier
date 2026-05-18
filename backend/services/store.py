"""In-memory resource store for the demo.

Production would use SQLite/Postgres. For 3-hour hackathon demo, dict is fine.
Resources reset on backend restart — acceptable for judging window.
"""

import uuid
from datetime import datetime
from typing import Dict, List, Optional

from models import (
    GenerationRequest, ResourceRecord, UpdateResourceRequest,
)

_RESOURCES: Dict[str, ResourceRecord] = {}


def save_resource(req: GenerationRequest, result: dict) -> ResourceRecord:
    """Save a freshly-generated resource."""
    rid = str(uuid.uuid4())
    now = datetime.utcnow()
    # Build a title from topic + grade
    title = f"{req.topic} — {req.grade}"
    if req.lesson:
        title = f"{req.topic} ({req.lesson})"

    record = ResourceRecord(
        id=rid,
        title=title,
        type=req.resource_type,
        subject=req.subject,
        grade=req.grade,
        lesson=req.lesson,
        content=result["markdown"],
        content_json=result.get("json"),
        created_at=now,
        updated_at=now,
        model_used=result["model_used"],
    )
    _RESOURCES[rid] = record
    return record


def list_resources() -> List[ResourceRecord]:
    """Return all resources, newest first."""
    return sorted(_RESOURCES.values(), key=lambda r: r.created_at, reverse=True)


def get_resource(rid: str) -> Optional[ResourceRecord]:
    return _RESOURCES.get(rid)


def update_resource(rid: str, req: UpdateResourceRequest) -> Optional[ResourceRecord]:
    r = _RESOURCES.get(rid)
    if r is None:
        return None
    updates = {}
    if req.title is not None:
        updates["title"] = req.title
    if req.content is not None:
        updates["content"] = req.content
    updates["updated_at"] = datetime.utcnow()
    r = r.model_copy(update=updates)
    _RESOURCES[rid] = r
    return r


def delete_resource(rid: str) -> bool:
    return _RESOURCES.pop(rid, None) is not None


def duplicate_resource(rid: str, new_title: str) -> Optional[ResourceRecord]:
    src = _RESOURCES.get(rid)
    if src is None:
        return None
    new_rid = str(uuid.uuid4())
    now = datetime.utcnow()
    copy = src.model_copy(update={
        "id": new_rid,
        "title": new_title,
        "created_at": now,
        "updated_at": now,
    })
    _RESOURCES[new_rid] = copy
    return copy
