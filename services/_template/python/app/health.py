from fastapi import APIRouter

router = APIRouter(tags=["health"])


@router.get("/health")
def live() -> dict[str, str]:
    return {"status": "ok", "service": "caption-svc"}


@router.get("/ready")
def ready() -> dict[str, str]:
    return {"status": "ready", "service": "caption-svc"}
