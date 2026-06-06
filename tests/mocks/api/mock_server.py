#!/usr/bin/env python3
"""Baobao mock-api 备用服务（无 Docker/Java 时用于 P0 冒烟）。"""
from __future__ import annotations

import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse

PORT = 18080
ACCESS_TOKEN = "mock_access_token_smoke"


def api_response(data=None, request_id: str = "req_mock") -> bytes:
    body = {"code": "OK", "message": "ok", "requestId": request_id}
    if data is not None:
        body["data"] = data
    return json.dumps(body, ensure_ascii=False, separators=(",", ":")).encode()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        print(f"[mock-api] {self.address_string()} - {fmt % args}")

    def _read_json(self) -> dict:
        length = int(self.headers.get("Content-Length", 0))
        if length <= 0:
            return {}
        raw = self.rfile.read(length)
        if not raw:
            return {}
        try:
            return json.loads(raw.decode("utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError):
            return {}

    def _send(self, status: int, body: bytes, content_type: str = "application/json") -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _auth_ok(self) -> bool:
        auth = self.headers.get("Authorization", "")
        return auth.startswith("Bearer ")

    def do_GET(self) -> None:
        path = urlparse(self.path).path
        if path == "/health":
            self._send(200, json.dumps({"status": "ok", "service": "baobao-mock-api-fallback"}).encode())
            return
        if path == "/v1/account/me":
            if not self._auth_ok():
                self._send(401, b'{"code":"UNAUTHORIZED"}')
                return
            self._send(
                200,
                api_response(
                    {
                        "nickname": "冒烟测试用户",
                        "avatarUrl": None,
                        "region": "cn",
                        "consents": {"childData": True},
                    },
                    "req_mock_account_me",
                ),
            )
            return
        self._send(404, b'{"code":"NOT_FOUND"}')

    def do_PUT(self) -> None:
        path = urlparse(self.path).path
        if path.startswith("/mock-oss/put/"):
            self._send(200, b"OK", "text/plain")
            return
        self._send(404, b'{"code":"NOT_FOUND"}')

    def do_POST(self) -> None:
        path = urlparse(self.path).path
        _ = self._read_json()

        if path == "/v1/auth/phone/code":
            self._send(200, api_response(request_id="req_mock_sms_send"))
            return

        if path == "/v1/auth/phone/login":
            self._send(
                200,
                api_response(
                    {
                        "userId": "usr_smoke_001",
                        "isNewUser": False,
                        "accessToken": ACCESS_TOKEN,
                        "accessTokenExpiresIn": 3600,
                        "refreshToken": "mock_refresh_token_smoke",
                        "refreshTokenExpiresIn": 2592000,
                        "profile": {
                            "nickname": "冒烟测试用户",
                            "avatarUrl": None,
                            "region": "cn",
                            "consents": {"childData": True},
                        },
                    },
                    "req_mock_phone_login",
                ),
            )
            return

        if not self._auth_ok():
            self._send(401, b'{"code":"UNAUTHORIZED"}')
            return

        if path == "/v1/uploads/init":
            self._send(
                200,
                api_response(
                    {
                        "uploadId": "upl_smoke_001",
                        "items": [
                            {
                                "clientRef": "photo-ref-001",
                                "objectKey": "mock/cn/fam_smoke_001/photo_smoke_001.jpg",
                                "uploadUrl": f"http://localhost:{PORT}/mock-oss/put/photo_smoke_001.jpg",
                                "headers": {"Content-Type": "image/jpeg"},
                                "expiresIn": 3600,
                            }
                        ],
                    },
                    "req_mock_upload_init",
                ),
            )
            return

        if path == "/v1/uploads/complete":
            self._send(
                200,
                api_response(
                    {
                        "uploadId": "upl_smoke_001",
                        "status": "completed",
                        "items": [
                            {
                                "clientRef": "photo-ref-001",
                                "objectKey": "mock/cn/fam_smoke_001/photo_smoke_001.jpg",
                                "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
                                "size": 1024,
                                "mime": "image/jpeg",
                            }
                        ],
                    },
                    "req_mock_upload_complete",
                ),
            )
            return

        if path == "/v1/posts":
            self._send(
                200,
                api_response(
                    {
                        "postId": "post_smoke_001",
                        "status": "published",
                        "familyId": "fam_smoke_001",
                        "babyId": "bb_smoke_001",
                        "media": [
                            {
                                "objectKey": "mock/cn/fam_smoke_001/photo_smoke_001.jpg",
                                "kind": "photo",
                                "width": 4032,
                                "height": 3024,
                            }
                        ],
                        "caption": "P0 冒烟发布（mock）",
                        "createdAt": "2026-06-06T00:00:00Z",
                    },
                    "req_mock_post_create",
                ),
            )
            return

        self._send(404, b'{"code":"NOT_FOUND"}')


def main() -> None:
    server = HTTPServer(("0.0.0.0", PORT), Handler)
    print(f"[mock-api] fallback listening on http://localhost:{PORT}")
    server.serve_forever()


if __name__ == "__main__":
    main()
