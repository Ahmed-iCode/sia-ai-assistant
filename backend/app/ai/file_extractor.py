import json
import logging
import re
import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional, List, Dict, Any
from zoneinfo import ZoneInfo
from google.genai import types

from app.core.config import settings
from app.db.models import User
from app.schemas.common import TaskPriority
from app.schemas.task import ExtractedTaskDraft, FileExtractionResponse
from app.ai.orchestrator import get_gemini_client, _call_gemini

logger = logging.getLogger(__name__)


def extract_schedule_from_file(
    file_bytes: bytes,
    mime_type: str,
    user: User,
    instruction: Optional[str] = None,
    timezone_name: str = "Africa/Cairo",
) -> FileExtractionResponse:
    """
    Extracts events, dates, and tasks from an uploaded image or PDF document
    using Gemini multimodal capabilities directly in memory.
    """
    try:
        user_tz = ZoneInfo(timezone_name)
    except Exception:
        user_tz = ZoneInfo("Africa/Cairo")
        timezone_name = "Africa/Cairo"

    now = datetime.now(user_tz)
    current_date_str = now.strftime("%Y-%m-%d")
    current_time_str = now.strftime("%H:%M")
    current_weekday = now.strftime("%A")

    ar_weekdays = {
        "Monday": "الإثنين",
        "Tuesday": "الثلاثاء",
        "Wednesday": "الأربعاء",
        "Thursday": "الخميس",
        "Friday": "الجمعة",
        "Saturday": "السبت",
        "Sunday": "الأحد",
    }
    ar_day_name = ar_weekdays.get(current_weekday, current_weekday)

    user_note = f"\n- User Special Instruction: {instruction.strip()}" if instruction and instruction.strip() else ""

    prompt_text = f"""You are Sia, an intelligent bilingual AI task and schedule assistant.
Your creator identity: T4S Team, led and developed by Ahmed Samir (فريق T4S بقيادة وتطوير أحمد سمير).
Strict Rule: Even when replying in Arabic, ALWAYS write your name in English letters as `Sia` — NEVER write `سيا` in Arabic script.

TASK:
Analyze the attached document (image or PDF) — such as a study timetable, exam schedule, prescription, work shift roster, appointment slip, or agenda — and extract all scheduled events, tasks, exams, appointments, or deadlines.

CURRENT REFERENCE CONTEXT:
- Today's Date: {current_date_str}
- Current Time: {current_time_str}
- Current Day of Week: {current_weekday} ({ar_day_name})
- Local Timezone: {timezone_name}{user_note}

EXTRACTION & DATE RESOLUTION RULES:
1. If the document specifies explicit calendar dates (e.g. '15 Dec 2026', '2026-12-15', '15 ديسمبر'):
   - Use that exact date and specified start/end times.
   - Convert to ISO-8601 UTC timestamps ending strictly with 'Z'.
2. If the document displays a recurring weekly schedule or mentions weekdays without specific dates (e.g. 'الأحد 10:00 ص', 'كل أربعاء 2 م', 'Monday 09:00 - 11:00'):
   - Calculate the date of the NEAREST UPCOMING occurrence of that weekday on or after today ({current_date_str}).
   - Combine that date with the specified start and end time in timezone '{timezone_name}', then convert the resulting timestamp to UTC ending with 'Z' (e.g. '2026-11-23T08:00:00Z').
3. For each extracted task:
   - "title": Concise, accurate title in the primary language of the document (e.g. 'امتحان الذكاء الاصطناعي', 'كشف دكتور أسنان', 'Math Lecture').
   - "description": Important details from the document (room, professor, dosage instructions, location) or null.
   - "start_time": ISO-8601 UTC string ending with 'Z'.
   - "end_time": ISO-8601 UTC string ending with 'Z'. If duration is unspecified, default to 1 hour after start_time.
   - "priority": one of ["urgent", "high", "medium", "low"]. Use "high" or "urgent" for exams, deadlines, or doctor appointments.
   - "category": Short category (e.g. "Study", "Work", "Health", "Personal").
   - "reminder_minutes": integer (default 15).
4. "reply": A warm, friendly, concise message from Sia in Egyptian Arabic (or English if document/instruction is in English) summarizing what was found and inviting the user to review the extracted tasks and confirm adding them. Remember: Even when replying in Arabic, ALWAYS write your name in English letters as `Sia` — NEVER write `سيا` in Arabic script.

OUTPUT FORMAT:
Return ONLY valid JSON with this structure:
{{
  "reply": "استخرجت لك 3 مواعيد من الجدول! راجعها واضغط تأكيد لإضافتها مباشرة.",
  "extracted_tasks": [
    {{
      "title": "امتحان الذكاء الاصطناعي",
      "description": "مدرج 4 - الدور الثاني",
      "start_time": "2026-11-25T08:00:00Z",
      "end_time": "2026-11-25T10:00:00Z",
      "priority": "high",
      "category": "Study",
      "reminder_minutes": 30
    }}
  ]
}}
"""

    client = get_gemini_client()
    contents = [
        types.Content(
            role="user",
            parts=[
                types.Part.from_bytes(data=file_bytes, mime_type=mime_type),
                types.Part.from_text(text=prompt_text),
            ],
        )
    ]
    config = types.GenerateContentConfig(
        response_mime_type="application/json",
        temperature=0.2,
    )

    resp = _call_gemini(client=client, contents=contents, config=config)

    # Extract text from response
    resp_text = ""
    if hasattr(resp, "text") and resp.text:
        resp_text = resp.text
    elif hasattr(resp, "candidates") and resp.candidates:
        c = resp.candidates[0]
        if hasattr(c, "content") and c.content and hasattr(c.content, "parts"):
            resp_text = "".join(
                p.text for p in c.content.parts if hasattr(p, "text") and p.text
            )

    # Clean markdown fences if present
    cleaned = resp_text.strip()
    if cleaned.startswith("```"):
        cleaned = re.sub(r"^```(?:json)?", "", cleaned).strip()
        cleaned = re.sub(r"```$", "", cleaned).strip()

    try:
        raw_data = json.loads(cleaned)
    except Exception as e:
        logger.error(f"Failed to parse Gemini extraction JSON: {e}\nRaw text: {resp_text}")
        return FileExtractionResponse(
            reply="لم أتمكن من استخراج المواعيد بشكل دقيق من هذا الملف. يُرجى التأكد من وضوح الصورة أو المستند والمحاولة مرة أخرى.",
            extracted_tasks=[],
        )

    reply = raw_data.get("reply", "تم استخراج المواعيد المقترحة بنجاح.")
    raw_tasks = raw_data.get("extracted_tasks", [])

    parsed_drafts: List[ExtractedTaskDraft] = []
    for item in raw_tasks:
        try:
            title = str(item.get("title", "")).strip()
            if not title:
                continue

            desc = item.get("description")
            start_str = item.get("start_time")
            end_str = item.get("end_time")

            # Parse start time
            st_clean = start_str.strip().replace(" ", "T")
            if not st_clean.endswith("Z") and "+" not in st_clean and "-" not in st_clean[10:]:
                st_clean += "Z"
            st = datetime.fromisoformat(st_clean.replace("Z", "+00:00"))
            if st.tzinfo is None:
                st = st.replace(tzinfo=timezone.utc)

            # Parse end time or default to 1 hour
            if end_str:
                et_clean = end_str.strip().replace(" ", "T")
                if not et_clean.endswith("Z") and "+" not in et_clean and "-" not in et_clean[10:]:
                    et_clean += "Z"
                et = datetime.fromisoformat(et_clean.replace("Z", "+00:00"))
                if et.tzinfo is None:
                    et = et.replace(tzinfo=timezone.utc)
            else:
                et = st + timedelta(hours=1)

            if et <= st:
                et = st + timedelta(hours=1)

            # Priority
            p_val = str(item.get("priority", "medium")).lower()
            try:
                priority = TaskPriority(p_val)
            except Exception:
                priority = TaskPriority.medium

            category = item.get("category")
            reminder_min = item.get("reminder_minutes", 15)
            try:
                reminder_min = int(reminder_min) if reminder_min is not None else 15
            except Exception:
                reminder_min = 15

            draft_id = f"draft-{uuid.uuid4().hex[:8]}"
            parsed_drafts.append(
                ExtractedTaskDraft(
                    id=draft_id,
                    title=title,
                    description=desc,
                    start_time=st,
                    end_time=et,
                    priority=priority,
                    category=category,
                    reminder_minutes=reminder_min,
                )
            )
        except Exception as item_err:
            logger.warning(f"Skipping malformed extracted task: {item_err}")
            continue

    return FileExtractionResponse(
        reply=reply,
        extracted_tasks=parsed_drafts,
    )
