from datetime import datetime
from app.schemas.common import CamelModel


class FreeSlotResponse(CamelModel):
    start: datetime
    end: datetime
    duration_minutes: int
