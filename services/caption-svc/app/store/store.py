from abc import ABC, abstractmethod
from typing import Any


class CaptionStore(ABC):
    @abstractmethod
    def ping(self) -> bool:
        raise NotImplementedError

    @abstractmethod
    def get_cached(self, cache_key: str) -> dict[str, Any] | None:
        raise NotImplementedError

    @abstractmethod
    def set_cached(self, cache_key: str, payload: dict[str, Any], ttl_seconds: int) -> None:
        raise NotImplementedError

    @abstractmethod
    def get_daily_count(self, user_id: str, day_key: str) -> int:
        raise NotImplementedError

    @abstractmethod
    def increment_daily_count(self, user_id: str, day_key: str, ttl_seconds: int) -> int:
        raise NotImplementedError
