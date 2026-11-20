import logging
from datetime import datetime, timezone
from typing import Optional, List, Any
from sqlalchemy.orm import Session
from google import genai
from google.genai import types
from google.genai.errors import ClientError, ServerError

from app.core.config import settings
from app.db.models import User, ChatMessage
from app.schemas.common import MessageSender
from app.schemas.action_card import (
    AiActionCardResponse,
    ChatMessageResponse,
    AssistantResponse,
)
from app.ai.prompts import build_system_prompt
from app.ai.tools import ToolExecutor, GEMINI_TOOL_DEFINITIONS

logger = logging.getLogger(__name__)

FALLBACK_MODELS = [
    settings.GEMINI_MODEL,
    "gemini-3.0-flash",
    "gemini-3.5-flash-lite",
    "gemini-3.8-flash",
]


def get_gemini_client() -> genai.Client:
    """
    Initializes Google GenAI client according to key format.
    Standard client directly authenticates API Studio and Express keys with zero latency.
    """
    api_key = settings.GEMINI_API_KEY
    if not api_key:
        raise ValueError("GEMINI_API_KEY is not configured.")

    try:
        return genai.Client(api_key=api_key)
    except Exception as e:
        logger.warning(f"Standard client init fallback: {e}")
        return genai.Client(vertexai=True, api_key=api_key)


def _call_gemini(
    client: genai.Client,
    contents: List[types.Content],
    config: types.GenerateContentConfig,
) -> Any:
    """
    Calls Gemini API with graceful model fallback if 404/503 occurs.
    """
    last_err = None
    # Ensure unique models list preserving order
    models_to_try = []
    for m in FALLBACK_MODELS:
        if m and m not in models_to_try:
            models_to_try.append(m)

    for model_name in models_to_try:
        try:
            return client.models.generate_content(
                model=model_name,
                contents=contents,
                config=config,
            )
        except ClientError as ce:
            # If 403 with vertexai, try standard AI Studio client
            if getattr(ce, "code", None) == 403 or "403" in str(ce):
                logger.warning("Vertex client got 403, attempting standard client...")
                try:
                    fallback_client = genai.Client(api_key=settings.GEMINI_API_KEY)
                    return fallback_client.models.generate_content(
                        model=model_name,
                        contents=contents,
                        config=config,
                    )
                except Exception as inner_e:
                    last_err = inner_e
            else:
                last_err = ce
        except ServerError as se:
            last_err = se
        except Exception as e:
            last_err = e

    if last_err:
        raise last_err
    raise RuntimeError("Failed to generate content with Gemini.")


class AgentOrchestrator:
    """
    Orchestrates user-agent conversation, multi-turn history,
    Gemini tool execution loop, and persistence.
    """

    def __init__(self, db: Session, user: User, client: Optional[genai.Client] = None):
        self.db = db
        self.user = user
        self.client = client or get_gemini_client()

    def process_message(
        self,
        text: str,
        is_voice: bool = False,
        audio_duration_seconds: Optional[int] = None,
        transcript: Optional[str] = None,
    ) -> AssistantResponse:
        """
        Executes a full assistant turn:
        1. Persists user message in chat_messages table.
        2. Loads recent conversation history.
        3. Calls Gemini with dynamic prompt and tool definitions.
        4. Runs tool execution loop (max 3 rounds) via ToolExecutor.
        5. Persists assistant response and structured Action Card.
        6. Returns AssistantResponse.
        """
        now_utc = datetime.now(timezone.utc)

        # 1. Save user message
        user_msg = ChatMessage(
            user_id=self.user.id,
            sender=MessageSender.user.value,
            text=text,
            is_voice=is_voice,
            audio_duration_seconds=audio_duration_seconds,
            timestamp=now_utc,
        )
        self.db.add(user_msg)
        self.db.flush()

        # 2. Build history from recent chat messages
        recent_history = (
            self.db.query(ChatMessage)
            .filter(ChatMessage.user_id == self.user.id)
            .order_by(ChatMessage.timestamp.desc())
            .limit(10)
            .all()
        )
        recent_history.reverse()

        contents: List[types.Content] = []
        for msg in recent_history:
            role = "user" if msg.sender == MessageSender.user.value else "model"
            contents.append(
                types.Content(
                    role=role,
                    parts=[types.Part.from_text(text=msg.text)],
                )
            )

        # If history was empty, at least include current message
        if not contents:
            contents.append(
                types.Content(
                    role="user",
                    parts=[types.Part.from_text(text=text)],
                )
            )

        # 3. Configure Gemini with system instructions & tools
        sys_prompt = build_system_prompt(self.user)
        config = types.GenerateContentConfig(
            system_instruction=sys_prompt,
            tools=GEMINI_TOOL_DEFINITIONS,
            automatic_function_calling=types.AutomaticFunctionCallingConfig(disable=True),
            temperature=0.2,
        )

        executor = ToolExecutor(db=self.db, user=self.user, is_voice=is_voice)

        # 4. Multi-round tool loop (up to 3 iterations)
        final_text = ""
        max_rounds = 3

        for _ in range(max_rounds):
            response = _call_gemini(self.client, contents, config)

            if not response.function_calls:
                final_text = response.text.strip() if response.text else "تم تنفيذ طلبك بنجاح."
                break

            # Model requested one or more tool calls
            model_turn = response.candidates[0].content
            tool_response_parts: List[types.Part] = []

            for call in response.function_calls:
                tool_result = executor.dispatch(call.name, call.args)
                tool_response_parts.append(
                    types.Part.from_function_response(
                        name=call.name,
                        response={"result": tool_result},
                    )
                )

            user_tool_turn = types.Content(role="user", parts=tool_response_parts)
            contents.extend([model_turn, user_tool_turn])

        if not final_text:
            final_text = "تم تنفيذ طلبك بنجاح."

        # 5. Persist assistant response
        card_data = (
            executor.action_card.model_dump(mode="json", by_alias=True)
            if executor.action_card
            else None
        )

        assistant_msg = ChatMessage(
            user_id=self.user.id,
            sender=MessageSender.assistant.value,
            text=final_text,
            is_voice=False,
            action_card_data=card_data,
            timestamp=datetime.now(timezone.utc),
        )
        self.db.add(assistant_msg)
        self.db.commit()
        self.db.refresh(assistant_msg)

        # 6. Format responses matching Dart CamelModel
        assistant_response_schema = ChatMessageResponse(
            id=assistant_msg.id,
            sender=MessageSender.assistant,
            text=final_text,
            timestamp=assistant_msg.timestamp,
            is_voice=False,
            audio_duration_seconds=None,
            action_card=executor.action_card,
        )

        return AssistantResponse(
            assistant_message=assistant_response_schema,
            action_card=executor.action_card,
            tasks_mutated=executor.tasks_mutated,
            transcript=transcript,
        )
