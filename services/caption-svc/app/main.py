from fastapi import FastAPI

from app.config import settings
from app.handlers.caption import router as caption_router
from app.health import router as health_router
from app.services.caption import CaptionService
from app.store.factory import create_store

app = FastAPI(title=settings.service_name, version="0.1.0")
app.include_router(health_router)
app.include_router(caption_router)


@app.on_event("startup")
def startup() -> None:
    store = create_store()
    app.state.store = store
    app.state.caption_service = CaptionService(store)
