import json
import logging
from typing import Any

import redis

from app.store.store import CaptionStore

logger = logging.getLogger(__name__)

CACHE_PREFIX = "caption:cache:"
LIMIT_PREFIX = "caption:limit:"


class RedisStore(CaptionStore):
    def __init__(self, url: str) -> None:
        self._client = redis.Redis.from_url(url, decode_responses=True)
        self._client.ping()

    def ping(self) -> bool:
        return bool(self._client.ping())

    def get_cached(self, cache_key: str) -> dict[str, Any] | None:
        raw = self._client.get(f"{CACHE_PREFIX}{cache_key}")
        if not raw:
            return None
        return json.loads(raw)

    def set_cached(self, cache_key: str, payload: dict[str, Any], ttl_seconds: int) -> None:
        self._client.setex(
            f"{CACHE_PREFIX}{cache_key}",
            ttl_seconds,
            json.dumps(payload, ensure_ascii=False),
        )

    def get_daily_count(self, user_id: str, day_key: str) -> int:
        value = self._client.get(f"{LIMIT_PREFIX}{user_id}:{day_key}")
        return int(value or 0)

    def increment_daily_count(self, user_id: str, day_key: str, ttl_seconds: int) -> int:
        key = f"{LIMIT_PREFIX}{user_id}:{day_key}"
        count = int(self._client.incr(key))
        if count == 1:
            self._client.expire(key, ttl_seconds)
        return count
