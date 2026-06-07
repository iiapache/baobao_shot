from typing import Any

from pydantic import BaseModel, Field


class CaptionCandidate(BaseModel):
    text: str
    hashtags: list[str] = Field(default_factory=list)


class CaptionGenerateRequest(BaseModel):
    baby_id: str = Field(alias="babyId")
    age_days: int = Field(alias="ageDays", ge=0)
    play: str | None = None
    location: str | None = None

    model_config = {"populate_by_name": True}


class CaptionGenerateResponse(BaseModel):
    candidates: list[CaptionCandidate]
    remaining_today: int = Field(alias="remainingToday")

    model_config = {"populate_by_name": True}


class SuccessResponse(BaseModel):
    code: str = "OK"
    message: str = ""
    request_id: str = Field(alias="requestId")
    data: Any = None

    model_config = {"populate_by_name": True}


class ErrorResponse(BaseModel):
    code: str
    message: str
    request_id: str = Field(alias="requestId")

    model_config = {"populate_by_name": True}
