from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse

from app.middleware.auth import get_request_id, get_user_id
from app.models.schemas import CaptionGenerateRequest, ErrorResponse, SuccessResponse
from app.services.caption import CaptionService, DailyLimitExceeded

router = APIRouter(tags=["caption"])


def _caption_service(request: Request) -> CaptionService:
    return request.app.state.caption_service


@router.post("/v1/caption/generate")
def generate_caption(request: Request, body: CaptionGenerateRequest) -> JSONResponse:
    user_id = get_user_id(request)
    if not user_id:
        payload = ErrorResponse(
            code="AUTH_UNAUTHORIZED",
            message="authentication required",
            request_id=get_request_id(request),
        )
        return JSONResponse(status_code=401, content=payload.model_dump(by_alias=True))

    service = _caption_service(request)
    try:
        result = service.generate(user_id, body)
    except DailyLimitExceeded:
        payload = ErrorResponse(
            code="CAPTION_DAILY_LIMIT",
            message="daily caption generation limit exceeded",
            request_id=get_request_id(request),
        )
        return JSONResponse(status_code=429, content=payload.model_dump(by_alias=True))

    payload = SuccessResponse(
        request_id=get_request_id(request),
        data=result.model_dump(by_alias=True),
    )
    return JSONResponse(status_code=200, content=payload.model_dump(by_alias=True))
