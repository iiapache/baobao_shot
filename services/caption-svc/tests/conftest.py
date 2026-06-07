import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services.caption import CaptionService
from app.store.memory import MemoryStore


@pytest.fixture
def memory_store() -> MemoryStore:
    return MemoryStore()


@pytest.fixture
def client(memory_store: MemoryStore) -> TestClient:
    app.state.store = memory_store
    app.state.caption_service = CaptionService(memory_store, daily_limit=50)
    return TestClient(app)
