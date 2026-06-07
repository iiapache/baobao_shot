from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse

from app.config import settings

router = APIRouter(tags=["health"])


@router.get("/health")
def live() -> dict[str, str]:
    return {"status": "ok", "service": settings.service_name}


@router.get("/ready")
def ready(request: Request) -> JSONResponse:
    store = request.app.state.store
    if store.ping():
        return JSONResponse(
            status_code=200,
            content={"status": "ready", "service": settings.service_name},
        )
    return JSONResponse(
        status_code=503,
        content={"status": "not_ready", "service": settings.service_name},
    )
