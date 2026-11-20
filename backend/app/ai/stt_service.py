import io
import logging
from typing import Optional
from fastapi import HTTPException, status
import groq
from app.core.config import settings

logger = logging.getLogger(__name__)

SUPPORTED_AUDIO_EXTENSIONS = {".m4a", ".wav", ".webm", ".mp3", ".ogg", ".flac", ".aac"}
MAX_AUDIO_SIZE_BYTES = 25 * 1024 * 1024  # 25 MB max


def get_groq_client() -> groq.Groq:
    if not settings.GROQ_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="GROQ_API_KEY is not configured.",
        )
    return groq.Groq(api_key=settings.GROQ_API_KEY)


def transcribe_audio(
    file_bytes: bytes,
    filename: str,
    client: Optional[groq.Groq] = None,
) -> str:
    """
    Transcribes audio bytes to text using Groq Whisper.
    Supports Egyptian Arabic, English, and mixed dialects.
    """
    if not file_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Audio file is empty.",
        )

    if len(file_bytes) > MAX_AUDIO_SIZE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Audio file exceeds maximum size limit of {MAX_AUDIO_SIZE_BYTES // (1024 * 1024)}MB.",
        )

    ext = ""
    if "." in filename:
        ext = "." + filename.rsplit(".", 1)[-1].lower()

    if ext and ext not in SUPPORTED_AUDIO_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported audio format '{ext}'. Supported: {', '.join(sorted(SUPPORTED_AUDIO_EXTENSIONS))}",
        )

    # Default to .wav if extension is missing or generic
    safe_filename = filename if ext in SUPPORTED_AUDIO_EXTENSIONS else "audio.wav"

    try:
        groq_client = client or get_groq_client()
        prompt_hint = (
            "محادثة يومية بالعامية المصرية والإنجليزية لتنظيم المهام والمواعيد والتقويم والتذكيرات "
            "Task Assistant, meetings, reminders, deadlines, work schedule"
        )
        transcription = groq_client.audio.transcriptions.create(
            file=(safe_filename, file_bytes),
            model=settings.WHISPER_MODEL,
            prompt=prompt_hint,
            temperature=0.0,
        )
        text = transcription.text.strip()
        if not text:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Could not detect speech in audio.",
            )
        return text
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Groq Whisper transcription error: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Audio transcription service failed: {str(e)}",
        )
