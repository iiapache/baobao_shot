from datetime import datetime, timedelta, timezone
from typing import Any

from app.config import settings
from app.models.schemas import (
    CaptionCandidate,
    CaptionGenerateRequest,
    CaptionGenerateResponse,
)
from app.services.generator import build_cache_key, generate_stub_candidates
from app.store.store import CaptionStore


class DailyLimitExceeded(Exception):
    pass


def _day_key(now: datetime | None = None) -> str:
    current = now or datetime.now(timezone.utc)
    return current.strftime("%Y-%m-%d")


def _seconds_until_day_end(now: datetime | None = None) -> int:
    current = now or datetime.now(timezone.utc)
    next_day = (current + timedelta(days=1)).replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    return max(int((next_day - current).total_seconds()), 1)


class CaptionService:
    def __init__(self, store: CaptionStore, daily_limit: int | None = None) -> None:
        self._store = store
        self._daily_limit = daily_limit or settings.daily_limit

    def generate(self, user_id: str, req: CaptionGenerateRequest) -> CaptionGenerateResponse:
        cache_key = build_cache_key(req)
        cached = self._store.get_cached(cache_key)
        if cached is not None:
            remaining = max(self._daily_limit - self._store.get_daily_count(user_id, _day_key()), 0)
            candidates = [CaptionCandidate(**item) for item in cached["candidates"]]
            return CaptionGenerateResponse(
                candidates=candidates,
                remaining_today=remaining,
            )

        day_key = _day_key()
        current = self._store.get_daily_count(user_id, day_key)
        if current >= self._daily_limit:
            raise DailyLimitExceeded()

        candidates = generate_stub_candidates(req)
        payload: dict[str, Any] = {
            "candidates": [item.model_dump() for item in candidates],
        }
        self._store.set_cached(cache_key, payload, settings.cache_ttl_seconds)

        used = self._store.increment_daily_count(
            user_id,
            day_key,
            _seconds_until_day_end(),
        )
        remaining = max(self._daily_limit - used, 0)
        return CaptionGenerateResponse(candidates=candidates, remaining_today=remaining)
