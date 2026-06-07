import logging

from app.config import settings
from app.store.memory import MemoryStore
from app.store.redis_store import RedisStore
from app.store.store import CaptionStore

logger = logging.getLogger(__name__)


def create_store(redis_url: str | None = None) -> CaptionStore:
    url = redis_url if redis_url is not None else settings.redis_url
    if not url:
        return MemoryStore()
    try:
        return RedisStore(url)
    except Exception as exc:
        logger.warning("redis unavailable; using memory fallback", exc_info=exc)
        return MemoryStore()
