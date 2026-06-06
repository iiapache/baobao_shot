from fastapi import FastAPI

from app.config import settings
from app.health import router as health_router

app = FastAPI(title=settings.service_name, version="0.1.0")
app.include_router(health_router)


@app.get("/v1/caption/generate")
def generate_caption_placeholder() -> dict[str, str]:
    """占位：智能文案生成 API，T2.x 接入模型。"""
    return {"status": "not_implemented", "message": "caption generation placeholder"}
