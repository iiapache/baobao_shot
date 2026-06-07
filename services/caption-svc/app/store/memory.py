from typing import Any

from app.store.store import CaptionStore


class MemoryStore(CaptionStore):
    def __init__(self) -> None:
        self._cache: dict[str, dict[str, Any]] = {}
        self._daily: dict[str, int] = {}

    def ping(self) -> bool:
        return True

    def get_cached(self, cache_key: str) -> dict[str, Any] | None:
        return self._cache.get(cache_key)

    def set_cached(self, cache_key: str, payload: dict[str, Any], ttl_seconds: int) -> None:
        del ttl_seconds
        self._cache[cache_key] = payload

    def get_daily_count(self, user_id: str, day_key: str) -> int:
        return self._daily.get(self._daily_key(user_id, day_key), 0)

    def increment_daily_count(self, user_id: str, day_key: str, ttl_seconds: int) -> int:
        del ttl_seconds
        key = self._daily_key(user_id, day_key)
        self._daily[key] = self._daily.get(key, 0) + 1
        return self._daily[key]

    @staticmethod
    def _daily_key(user_id: str, day_key: str) -> str:
        return f"{user_id}:{day_key}"
