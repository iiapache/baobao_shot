import uuid

from fastapi import Request


def parse_dev_token(token: str) -> str | None:
    if not token or token == "invalid":
        return None
    if token == "dev":
        return "usr_dev"
    if token.startswith("dev:"):
        return token[4:]
    if token.startswith("atk_"):
        body = token[4:]
        idx = body.rfind("_")
        if idx > 0:
            return body[:idx]
    return None


def get_user_id(request: Request) -> str | None:
    header_user = request.headers.get("X-User-Id", "").strip()
    if header_user:
        return header_user

    auth_header = request.headers.get("Authorization", "")
    if auth_header.startswith("Bearer "):
        token = auth_header[7:].strip()
        return parse_dev_token(token)
    return None


def get_request_id(request: Request) -> str:
    for header in ("X-Request-Id", "X-Trace-Id"):
        value = request.headers.get(header, "").strip()
        if value:
            return value
    return f"req_{uuid.uuid4().hex[:8]}"
