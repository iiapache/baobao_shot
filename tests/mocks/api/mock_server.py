#!/usr/bin/env python3
"""Baobao mock-api 备用服务（无 Docker/Java 时用于 P0/P3/P4/P5/P6/P7 冒烟）。"""
from __future__ import annotations

import hashlib
import hmac
import io
import json
import time
import zipfile
from datetime import date, datetime, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

PORT = 18080
ACCESS_TOKEN_ADMIN = "mock_access_token_admin"
ACCESS_TOKEN_MEMBER = "mock_access_token_member"
ACCESS_TOKEN = ACCESS_TOKEN_ADMIN  # P0 兼容
FAMILY_ID = "fam_e2e_001"
INVITE_CODE = "888888"
BABY_ID = "bb_e2e_001"
AI_INPUT_KEY = "ai-tmp/usr_e2e_admin/e2e-input.heic"

# P3 E2E：内存任务状态（轮询 / 弱网 / 切后台 mock）
AI_TASKS: dict[str, dict] = {}

# P4 E2E：积分 / 订阅 / 广告内存状态
SIGNUP_CREDITS = 100
INVITE_CREDITS = 50
AD_REWARD_CREDITS = 5
AD_DAILY_LIMIT = 5
PANGLE_MOCK_SECRET = "mock-pangle-secret"

IAP_PRODUCT_CREDITS = {
    "com.baobao.credits.100": 100,
    "com.baobao.credits.60": 60,
    "credit_pack_60": 60,
    "credit_pack_330": 330,
    "credit_pack_800": 800,
    "credit_pack_2500": 2500,
}

ENTITLEMENTS_ACTIVE = {
    "removeAds": True,
    "brandWatermarkRemovable": True,
    "allFilters": True,
    "annualReviewRegen": True,
}
ENTITLEMENTS_NONE = {
    "removeAds": False,
    "brandWatermarkRemovable": False,
    "allFilters": False,
    "annualReviewRegen": False,
}

CREDIT_USERS: dict[str, dict] = {}

# P5 E2E：家庭圈 / 通知 / 智能文案 / 分享 mock 状态
CAPTION_DAILY_LIMIT = 50
POST_RATE_WINDOW_SEC = 60
POST_RATE_MAX = 5
FAMILY_MEMBERS = {"usr_e2e_admin", "usr_e2e_member"}

POSTS: dict[str, dict] = {}
COMMENTS: dict[str, dict] = {}
LIKES: set[tuple[str, str]] = set()
NOTIFICATIONS: dict[str, list[dict]] = {}
CAPTION_USERS: dict[str, dict] = {}
CAPTION_CACHE: dict[str, dict] = {}
UGC_APPEALS: dict[str, dict] = {}
POST_CREATE_TIMES: dict[str, list[float]] = {}
_post_seq = 0
_comment_seq = 0
_notif_seq = 0

# P6 E2E：备份凭据 / 状态 / 数据导出 mock 状态
BACKUP_PROVIDERS: dict[str, dict[str, dict]] = {}
BACKUP_STATUS: dict[str, dict] = {}
ACCOUNT_EXPORTS: dict[str, dict] = {}
_backup_provider_seq = 0

# P7 E2E：内容审核 CN/OS 双区 mock 状态
AUDIT_JOBS: dict[str, dict] = {}
AUDIT_APPEALS: dict[str, dict] = {}
_audit_job_seq = 0
_audit_appeal_seq = 0


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _next_post_id() -> str:
    global _post_seq
    _post_seq += 1
    return f"pst_e2e_{_post_seq:04d}"


def _next_comment_id() -> str:
    global _comment_seq
    _comment_seq += 1
    return f"cmt_e2e_{_comment_seq:04d}"


def _next_notif_id() -> str:
    global _notif_seq
    _notif_seq += 1
    return f"ntf_e2e_{_notif_seq:04d}"


def _next_backup_provider_id() -> str:
    global _backup_provider_seq
    _backup_provider_seq += 1
    return f"bkp_e2e_{_backup_provider_seq:04d}"


def _valid_backup_kind(kind: str) -> bool:
    return kind in {"icloud", "baidu_pan", "photos"}


def _user_backup_providers(user_id: str) -> dict[str, dict]:
    return BACKUP_PROVIDERS.setdefault(user_id, {})


def _backup_provider_dto(provider: dict) -> dict:
    return {
        "id": provider["id"],
        "kind": provider["kind"],
        "status": provider.get("status", "active"),
        "providerAccountId": provider.get("providerAccountId"),
        "expiresAt": provider.get("expiresAt"),
        "metadata": provider.get("metadata") or {},
        "createdAt": provider["createdAt"],
        "updatedAt": provider["updatedAt"],
    }


def _backup_status_dto(user_id: str) -> dict:
    status = BACKUP_STATUS.get(user_id, {})
    return {
        "lastSuccessAt": status.get("lastSuccessAt"),
        "lastAttemptAt": status.get("lastAttemptAt"),
        "failureCount": int(status.get("failureCount", 0)),
        "lastErrorCode": status.get("lastErrorCode"),
    }


def _make_export_sample_zip() -> bytes:
    manifest = json.dumps(
        {
            "version": "1.0",
            "exportedAt": _utc_now_iso(),
            "babyCount": 1,
            "photoCount": 1,
            "photos": [{"id": "photo_1", "archivePath": "photos/photo_1.heic"}],
        },
        ensure_ascii=False,
    ).encode("utf-8")
    html = b"<!DOCTYPE html><html><body><h1>Baobao Export Preview</h1></body></html>"
    photo = b"MOCK_HEIC_BYTES"
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("manifest.json", manifest)
        zf.writestr("timeline.html", html)
        zf.writestr("photos/photo_1.heic", photo)
    return buf.getvalue()


def _ugc_reject(text: str) -> bool:
    lowered = (text or "").lower()
    return "reject_spam" in lowered or "违规文字" in lowered


def _next_audit_job_id() -> str:
    global _audit_job_seq
    _audit_job_seq += 1
    return f"aud_e2e_{_audit_job_seq:04d}"


def _next_audit_appeal_id() -> str:
    global _audit_appeal_seq
    _audit_appeal_seq += 1
    return f"apl_audit_{_audit_appeal_seq:04d}"


def _audit_media_type(body: dict) -> str:
    media = str(body.get("mediaType") or "").strip().lower()
    if media:
        return media
    text = str(body.get("text") or "").strip()
    if text:
        return "text"
    key = str(body.get("objectKey") or "").strip().lower()
    if not key:
        return ""
    if key.endswith((".mp4", ".mov", ".webm")):
        return "video"
    return "image"


def _audit_markers(body: dict) -> str:
    parts = [
        str(body.get("text") or "").lower(),
        str(body.get("objectKey") or "").lower(),
        str(body.get("targetRef") or "").lower(),
    ]
    return " ".join(p for p in parts if p)


def _cn_audit_reasons(marker: str, media_type: str) -> list[str]:
    if "reject_porn" in marker or "违规色情" in marker:
        return ["porn"]
    if "reject_terror" in marker or "违规暴恐" in marker:
        return ["terrorism"]
    if "reject_spam" in marker or "违规文字" in marker:
        return ["antispam"]
    if "reject" in marker:
        if media_type == "text":
            return ["antispam", "abuse"]
        if media_type == "video":
            return ["porn", "terrorism"]
        return ["porn"]
    return []


def _os_audit_reasons(marker: str, media_type: str) -> list[str]:
    if "audit-reject-rekognition" in marker:
        return ["aws_rekognition:moderation_failed"]
    if "audit-reject-cloudflare" in marker:
        return ["cloudflare_guard:unsafe_content"]
    if "audit-reject-openai" in marker:
        return ["openai_moderation:flagged"]
    if "reject_spam" in marker or "reject_porn" in marker or "reject_terror" in marker or "reject" in marker:
        if media_type == "text":
            return ["openai_moderation:flagged"]
        if media_type == "video":
            return ["aws_rekognition:moderation_failed"]
        return ["aws_rekognition:moderation_failed", "cloudflare_guard:unsafe_content"]
    return []


def _audit_vendor(region: str, media_type: str) -> str:
    if region == "os":
        if media_type == "text":
            return "openai-moderation"
        if media_type == "video":
            return "aws-rekognition"
        return "aws-rekognition+cloudflare-guard"
    return "aliyun-green"


def _audit_decision(body: dict) -> tuple[bool, list[str], str]:
    region = str(body.get("region") or "cn").strip().lower()
    if region not in ("cn", "os"):
        raise ValueError("invalid region")
    media_type = _audit_media_type(body)
    marker = _audit_markers(body)
    reasons = _cn_audit_reasons(marker, media_type) if region == "cn" else _os_audit_reasons(marker, media_type)
    vendor = _audit_vendor(region, media_type)
    return len(reasons) == 0, reasons, vendor


def _audit_job_dto(job: dict) -> dict:
    return {
        "jobId": job["jobId"],
        "kind": job["kind"],
        "targetRef": job["targetRef"],
        "status": job["status"],
        "result": job.get("result", job["status"]),
        "reasons": job.get("reasons") or [],
        "vendor": job.get("vendor", ""),
        "region": job.get("region", "cn"),
        "mediaType": job.get("mediaType", ""),
        "createdAt": job.get("createdAt"),
        "completedAt": job.get("completedAt"),
    }


def _caption_baby_label(baby_id: str) -> str:
    suffix = baby_id.rsplit("_", 1)[-1]
    if suffix and suffix != baby_id:
        return f"宝宝{suffix[:4]}"
    return "宝宝"


def _caption_play_label(play: str | None) -> str:
    labels = {
        "ghibli_kid": "吉卜力小主角",
        "cartoon": "卡通版",
        "watercolor": "水彩风",
        "storybook": "绘本风",
    }
    if not play:
        return "成长瞬间"
    return labels.get(play, play.replace("_", " "))


def _caption_cache_key(body: dict) -> str:
    payload = {
        "babyId": body.get("babyId", ""),
        "ageDays": body.get("ageDays", 0),
        "play": body.get("play") or "",
        "location": body.get("location") or "",
    }
    digest = hashlib.sha256(
        json.dumps(payload, sort_keys=True, ensure_ascii=False).encode("utf-8")
    ).hexdigest()
    return digest


def _caption_candidates(body: dict) -> list[dict]:
    baby = _caption_baby_label(str(body.get("babyId", "")))
    play = _caption_play_label(body.get("play"))
    location = body.get("location") or "今天"
    age = int(body.get("ageDays") or 0)
    return [
        {"text": f"{baby} · 第 {age} 天 · 化身{play} 🌿", "hashtags": ["#宝宝成长", f"#{play}"]},
        {"text": f"{location}的小晴天里，第 {age} 天的{baby} ✨", "hashtags": ["#日常打卡"]},
        {"text": f"AI 帮我画了一个童话版的{baby} 💫", "hashtags": ["#AI共创"]},
    ]


def _ensure_caption_user(user_id: str) -> dict:
    if user_id not in CAPTION_USERS:
        CAPTION_USERS[user_id] = {"day": None, "count": 0}
    return CAPTION_USERS[user_id]


def _push_family_notification(post: dict) -> None:
    owner = post.get("ownerUserId", "")
    for member_id in FAMILY_MEMBERS:
        if member_id == owner:
            continue
        NOTIFICATIONS.setdefault(member_id, []).insert(
            0,
            {
                "id": _next_notif_id(),
                "category": "FAMILY_ACTIVITY",
                "payload": {
                    "kind": "post_published",
                    "postId": post["postId"],
                    "familyId": post.get("familyId"),
                    "caption": post.get("caption", ""),
                    "ownerUserId": owner,
                },
                "readAt": None,
                "createdAt": post.get("createdAt", _utc_now_iso()),
            },
        )


def _visible_posts(family_id: str) -> list[dict]:
    items = [
        p
        for p in POSTS.values()
        if p.get("familyId") == family_id and p.get("status") in ("published", "audit")
    ]
    items.sort(key=lambda p: p.get("createdAt", ""), reverse=True)
    return items


def api_response(data=None, request_id: str = "req_mock") -> bytes:
    body = {"code": "OK", "message": "ok", "requestId": request_id}
    if data is not None:
        body["data"] = data
    return json.dumps(body, ensure_ascii=False, separators=(",", ":")).encode()


def api_error(code: str, message: str = "", status_hint: int = 400) -> tuple[int, bytes]:
    body = {"code": code, "message": message or code, "requestId": "req_mock_err"}
    return status_hint, json.dumps(body, ensure_ascii=False, separators=(",", ":")).encode()


def _today_utc() -> date:
    return datetime.now(timezone.utc).date()


def _ensure_credit_user(user_id: str) -> dict:
    if user_id not in CREDIT_USERS:
        CREDIT_USERS[user_id] = {
            "balance": SIGNUP_CREDITS,
            "sign_in_date": None,
            "streak": 0,
            "iap_txs": set(),
            "ad_today": 0,
            "ad_trans": set(),
            "subscription": None,
            "ledger": [],
            "invite_grants": set(),
        }
    return CREDIT_USERS[user_id]


def _append_ledger(user: dict, entry_type: str, amount: int, ref_kind: str, ref_id: str) -> str:
    ledger_id = f"led_{len(user['ledger']) + 1:04d}"
    user["ledger"].append(
        {
            "id": ledger_id,
            "type": entry_type,
            "amount": amount,
            "refKind": ref_kind,
            "refId": ref_id,
            "balanceAfter": user["balance"],
            "createdAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        }
    )
    return ledger_id


def _grant_credits(user: dict, amount: int, ref_kind: str, ref_id: str) -> tuple[int, str]:
    user["balance"] += amount
    ledger_id = _append_ledger(user, "grant", amount, ref_kind, ref_id)
    return amount, ledger_id


def _subscription_me(user: dict, scenario: str = "") -> dict:
    sub = user.get("subscription")
    if scenario == "sub_grace" and sub:
        return {
            "active": True,
            "state": "grace",
            "sku": sub.get("sku"),
            "periodStart": sub.get("periodStart"),
            "periodEnd": sub.get("periodEnd"),
            "autoRenew": True,
            "cacheTtlSeconds": 600,
            "entitlements": ENTITLEMENTS_ACTIVE,
            "subscriptionId": sub.get("subscriptionId"),
        }
    if sub:
        state = sub.get("state", "none")
        if state == "refunded":
            return {
                "active": False,
                "state": "refunded",
                "sku": sub.get("sku"),
                "cacheTtlSeconds": 600,
                "entitlements": ENTITLEMENTS_NONE,
                "subscriptionId": sub.get("subscriptionId"),
            }
        if state == "expired":
            return {
                "active": False,
                "state": "expired",
                "sku": sub.get("sku"),
                "cacheTtlSeconds": 600,
                "entitlements": ENTITLEMENTS_NONE,
                "subscriptionId": sub.get("subscriptionId"),
            }
        if state in ("active", "trial", "grace"):
            active = True
            ents = ENTITLEMENTS_ACTIVE
            if state == "grace":
                active = True
            return {
                "active": active,
                "state": state,
                "sku": sub.get("sku"),
                "periodStart": sub.get("periodStart"),
                "periodEnd": sub.get("periodEnd"),
                "autoRenew": sub.get("autoRenew", True),
                "cacheTtlSeconds": 600,
                "entitlements": ents,
                "subscriptionId": sub.get("subscriptionId"),
            }
    return {
        "active": False,
        "state": "none",
        "cacheTtlSeconds": 600,
        "entitlements": ENTITLEMENTS_NONE,
    }


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

    def _user_id(self) -> str:
        auth = self.headers.get("Authorization", "")
        if ACCESS_TOKEN_MEMBER in auth or "usr_e2e_member" in auth:
            return "usr_e2e_member"
        if "dev:" in auth:
            return auth.split("dev:", 1)[-1].strip()
        return "usr_e2e_admin"

    def do_PATCH(self) -> None:
        path = urlparse(self.path).path
        body = self._read_json()
        if not self._auth_ok():
            self._send(401, b'{"code":"UNAUTHORIZED"}')
            return
        if path == "/v1/account/me":
            self._send(
                200,
                api_response(
                    {
                        "nickname": body.get("nickname", "E2E管理员"),
                        "avatarUrl": None,
                        "region": "cn",
                        "consents": {"childData": False},
                    },
                    "req_mock_account_update",
                ),
            )
            return
        if path == "/v1/notifications/subscriptions":
            patches = body.get("subscriptions") or []
            subs = [
                {"category": "MILESTONE", "enabled": True},
                {"category": "FAMILY_ACTIVITY", "enabled": True},
                {"category": "AI_DONE", "enabled": True},
                {"category": "CREDIT", "enabled": True},
                {"category": "SYSTEM", "enabled": False},
            ]
            by_cat = {s["category"]: s for s in subs}
            for p in patches:
                cat = p.get("category")
                if cat in by_cat and "enabled" in p:
                    by_cat[cat]["enabled"] = bool(p["enabled"])
            self._send(
                200,
                api_response({"subscriptions": list(by_cat.values())}, "req_mock_notif_subs_patch"),
            )
            return
        self._send(404, b'{"code":"NOT_FOUND"}')

    def do_DELETE(self) -> None:
        path = urlparse(self.path).path
        if not self._auth_ok():
            self._send(401, b'{"code":"UNAUTHORIZED"}')
            return
        if path == "/v1/account":
            self._send(
                200,
                api_response(
                    {
                        "requestedAt": "2026-06-06T10:00:00Z",
                        "scheduledAt": "2026-06-13T10:00:00Z",
                        "revokeBefore": "2026-06-13T10:00:00Z",
                    },
                    "req_mock_account_delete",
                ),
            )
            return
        if path.startswith("/v1/posts/") and path.endswith("/likes") and path.count("/") == 4:
            post_id = path.split("/")[3]
            user_id = self._user_id()
            key = (post_id, user_id)
            removed = key in LIKES
            LIKES.discard(key)
            self._send(
                200,
                api_response(
                    {"postId": post_id, "userId": user_id, "removed": removed},
                    "req_mock_post_unlike",
                ),
            )
            return
        if path.endswith("/comments/") or ("/comments/" in path and path.startswith("/v1/posts/")):
            parts = path.strip("/").split("/")
            if len(parts) == 5 and parts[0] == "v1" and parts[1] == "posts" and parts[3] == "comments":
                post_id, comment_id = parts[2], parts[4]
                comment = COMMENTS.get(comment_id)
                if not comment or comment.get("postId") != post_id:
                    status, err = api_error("COMMON_NOT_FOUND", status_hint=404)
                    self._send(status, err)
                    return
                if comment.get("userId") != self._user_id():
                    status, err = api_error("COMMON_FORBIDDEN", status_hint=403)
                    self._send(status, err)
                    return
                comment["removed"] = True
                self._send(
                    200,
                    api_response(
                        {"commentId": comment_id, "postId": post_id, "removed": True},
                        "req_mock_comment_delete",
                    ),
                )
                return
        if path.startswith("/v1/posts/") and path.count("/") == 3:
            post_id = path.rsplit("/", 1)[-1]
            self._handle_post_delete(post_id)
            return
        if path.startswith("/v1/notifications/devices/") and path.count("/") == 4:
            device_id = path.rsplit("/", 1)[-1]
            self._send(200, api_response({"deviceId": device_id}, "req_mock_device_unregister"))
            return
        if path.startswith("/v1/backup/providers/") and path.count("/") == 4:
            provider_id = path.rsplit("/", 1)[-1]
            self._handle_backup_unbind(provider_id)
            return
        self._send(404, b'{"code":"NOT_FOUND"}')

    def do_GET(self) -> None:
        path = urlparse(self.path).path
        if path == "/health":
            self._send(200, json.dumps({"status": "ok", "service": "baobao-mock-api-fallback"}).encode())
            return
        if path.startswith("/v1/audit/jobs/") and path.count("/") == 4:
            job_id = path.rsplit("/", 1)[-1]
            job = AUDIT_JOBS.get(job_id)
            if not job:
                self._send(404, json.dumps({"error": "audit job not found"}).encode())
                return
            self._send(200, json.dumps(_audit_job_dto(job), ensure_ascii=False).encode())
            return
        if path.startswith("/mock-ai/result/"):
            self._send(200, b"MOCK_AI_RESULT", "application/octet-stream")
            return
        if path.startswith("/v1/ai/tasks/") and path.count("/") == 4:
            if not self._auth_ok():
                self._send(401, b'{"code":"UNAUTHORIZED"}')
                return
            task_id = path.rsplit("/", 1)[-1]
            self._send(200, api_response(self._ai_task_detail(task_id), f"req_mock_ai_get_{task_id}"))
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
        if path == "/v1/account/consents/child-data":
            if not self._auth_ok():
                self._send(401, b'{"code":"UNAUTHORIZED"}')
                return
            self._send(
                200,
                api_response(
                    {
                        "currentVersion": "child_consent_v1",
                        "agreedVersion": "child_consent_v1",
                        "agreed": True,
                        "agreedAt": "2026-06-06T10:00:00Z",
                        "requiresConsent": False,
                    },
                    "req_mock_consent_status",
                ),
            )
            return
        if path == "/v1/ai/plays":
            if not self._auth_ok():
                self._send(401, b'{"code":"UNAUTHORIZED"}')
                return
            self._send(
                200,
                api_response(
                    {
                        "version": "20250606001",
                        "region": "cn",
                        "ttlSeconds": 300,
                        "plays": [
                            {
                                "id": "ghibli_kid",
                                "name": "宫崎骏风",
                                "kind": "image",
                                "creditCost": 8,
                                "available": True,
                            },
                            {
                                "id": "video_walk",
                                "name": "图生视频",
                                "kind": "video",
                                "available": True,
                                "durationTiers": [
                                    {"durationSeconds": 5, "creditCost": 60},
                                    {"durationSeconds": 10, "creditCost": 120},
                                ],
                            },
                        ],
                    },
                    "req_mock_ai_plays",
                ),
            )
            return
        if path.startswith("/v1/families/") and path.endswith("/members"):
            if not self._auth_ok():
                self._send(401, b'{"code":"UNAUTHORIZED"}')
                return
            self._send(
                200,
                api_response(
                    {
                        "items": [
                            {
                                "userId": "usr_e2e_admin",
                                "role": "admin",
                                "nickname": "E2E管理员",
                                "joinedAt": "2026-06-06T09:00:00Z",
                            },
                            {
                                "userId": "usr_e2e_member",
                                "role": "family",
                                "nickname": "外婆",
                                "joinedAt": "2026-06-06T10:00:00Z",
                            },
                        ]
                    },
                    "req_mock_family_members",
                ),
            )
            return
        if path == "/v1/credits/balance":
            if not self._auth_ok():
                self._send(401, b'{"code":"UNAUTHORIZED"}')
                return
            user = _ensure_credit_user(self._user_id())
            today = _today_utc()
            sign_in_available = user["sign_in_date"] != today
            self._send(
                200,
                api_response(
                    {"balance": user["balance"], "signInAvailable": sign_in_available},
                    "req_mock_credits_balance",
                ),
            )
            return
        if path == "/v1/credits/transactions":
            if not self._auth_ok():
                self._send(401, b'{"code":"UNAUTHORIZED"}')
                return
            user = _ensure_credit_user(self._user_id())
            qs = parse_qs(urlparse(self.path).query)
            limit = min(int(qs.get("limit", ["20"])[0]), 50)
            items = list(reversed(user["ledger"]))[:limit]
            self._send(
                200,
                api_response({"items": items, "nextCursor": None}, "req_mock_credits_tx"),
            )
            return
        if path == "/v1/credits/rates":
            if not self._auth_ok():
                self._send(401, b'{"code":"UNAUTHORIZED"}')
                return
            self._send(
                200,
                api_response(
                    {
                        "version": "20250606001",
                        "plays": [
                            {"playId": "ghibli_kid", "kind": "image", "creditCost": 8},
                            {
                                "playId": "video_walk",
                                "kind": "video",
                                "durationTiers": [
                                    {"durationSeconds": 5, "creditCost": 60},
                                    {"durationSeconds": 10, "creditCost": 120},
                                ],
                            },
                        ],
                        "rechargePacks": [
                            {"productId": "com.baobao.credits.100", "credits": 100, "priceCny": 10},
                            {"productId": "credit_pack_330", "credits": 330, "priceCny": 30},
                        ],
                    },
                    "req_mock_credits_rates",
                ),
            )
            return
        if path == "/v1/subscriptions/me":
            if not self._auth_ok():
                self._send(401, b'{"code":"UNAUTHORIZED"}')
                return
            user = _ensure_credit_user(self._user_id())
            scenario = self.headers.get("X-E2E-Scenario", "")
            self._send(
                200,
                api_response(_subscription_me(user, scenario), "req_mock_sub_me"),
            )
            return
        if path == "/v1/subscriptions/products":
            if not self._auth_ok():
                self._send(401, b'{"code":"UNAUTHORIZED"}')
                return
            self._send(
                200,
                api_response(
                    {
                        "region": "cn",
                        "products": [
                            {
                                "productId": "com.baobao.sub.monthly",
                                "title": "月度会员",
                                "priceCny": 18,
                                "period": "month",
                                "trialDays": 7,
                            }
                        ],
                    },
                    "req_mock_sub_products",
                ),
            )
            return
        if path == "/v1/feeds/family":
            if not self._auth_ok():
                self._send(401, b'{"code":"UNAUTHORIZED"}')
                return
            qs = parse_qs(urlparse(self.path).query)
            family_id = qs.get("familyId", [FAMILY_ID])[0]
            limit = min(int(qs.get("limit", ["20"])[0]), 50)
            items = _visible_posts(family_id)[:limit]
            self._send(
                200,
                api_response(
                    {"items": items, "nextCursor": None, "cacheTtlSeconds": 60},
                    "req_mock_feed_list",
                ),
            )
            return
        if path.startswith("/v1/posts/") and path.count("/") == 3:
            if not self._auth_ok():
                self._send(401, b'{"code":"UNAUTHORIZED"}')
                return
            post_id = path.rsplit("/", 1)[-1]
            post = POSTS.get(post_id)
            if not post or post.get("status") == "removed":
                status, err = api_error("COMMON_NOT_FOUND", status_hint=404)
                self._send(status, err)
                return
            self._send(200, api_response(post, f"req_mock_post_get_{post_id}"))
            return
        if path.endswith("/comments") and path.startswith("/v1/posts/") and path.count("/") == 4:
            if not self._auth_ok():
                self._send(401, b'{"code":"UNAUTHORIZED"}')
                return
            post_id = path.split("/")[3]
            items = [
                c
                for c in COMMENTS.values()
                if c.get("postId") == post_id and not c.get("removed")
            ]
            items.sort(key=lambda c: c.get("createdAt", ""))
            self._send(
                200,
                api_response({"items": items, "nextCursor": None}, "req_mock_post_comments"),
            )
            return
        if path == "/v1/notifications":
            if not self._auth_ok():
                self._send(401, b'{"code":"UNAUTHORIZED"}')
                return
            user_id = self._user_id()
            qs = parse_qs(urlparse(self.path).query)
            limit = min(int(qs.get("limit", ["50"])[0]), 50)
            items = list(NOTIFICATIONS.get(user_id, []))[:limit]
            unread = sum(1 for n in items if not n.get("readAt"))
            self._send(
                200,
                api_response(
                    {"items": items, "unreadCount": unread, "nextCursor": None},
                    "req_mock_notifications_list",
                ),
            )
            return
        if path == "/v1/notifications/subscriptions":
            if not self._auth_ok():
                self._send(401, b'{"code":"UNAUTHORIZED"}')
                return
            subs = [
                {"category": "MILESTONE", "enabled": True},
                {"category": "FAMILY_ACTIVITY", "enabled": True},
                {"category": "AI_DONE", "enabled": True},
                {"category": "CREDIT", "enabled": True},
                {"category": "SYSTEM", "enabled": False},
            ]
            self._send(
                200,
                api_response({"subscriptions": subs}, "req_mock_notif_subs_get"),
            )
            return
        if path == "/v1/backup/providers":
            if not self._auth_ok():
                self._send(401, b'{"code":"UNAUTHORIZED"}')
                return
            self._handle_backup_list()
            return
        if path == "/v1/backup/status":
            if not self._auth_ok():
                self._send(401, b'{"code":"UNAUTHORIZED"}')
                return
            self._handle_backup_get_status()
            return
        if path == "/v1/e2e/backup/export-sample":
            if not self._auth_ok():
                self._send(401, b'{"code":"UNAUTHORIZED"}')
                return
            self._send(200, _make_export_sample_zip(), "application/zip")
            return
        if path == "/v1/e2e/backup/widget-kinds":
            self._send(
                200,
                api_response(
                    {
                        "kinds": [
                            {"kind": "BabyCameraWidgetSmall", "family": "systemSmall"},
                            {"kind": "BabyCameraWidgetMedium", "family": "systemMedium"},
                            {"kind": "BabyCameraWidgetLarge", "family": "systemLarge"},
                            {"kind": "BabyCameraWidgetLockScreen", "family": "accessoryCircular"},
                        ]
                    },
                    "req_mock_widget_kinds",
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
        body = self._read_json()
        _ = body

        if path == "/v1/auth/phone/code":
            self._send(200, api_response(request_id="req_mock_sms_send"))
            return

        if path == "/v1/auth/phone/login":
            phone = body.get("phone", "")
            if phone == "13800138002":
                user_id = "usr_e2e_member"
                token = ACCESS_TOKEN_MEMBER
                nickname = "E2E家庭成员"
            else:
                user_id = "usr_e2e_admin"
                token = ACCESS_TOKEN_ADMIN
                nickname = "E2E管理员"
            self._send(
                200,
                api_response(
                    {
                        "userId": user_id,
                        "isNewUser": True,
                        "accessToken": token,
                        "accessTokenExpiresIn": 3600,
                        "refreshToken": f"mock_refresh_{user_id}",
                        "refreshTokenExpiresIn": 2592000,
                        "profile": {
                            "nickname": nickname,
                            "avatarUrl": None,
                            "region": "cn",
                            "consents": {"childData": False},
                        },
                    },
                    "req_mock_phone_login",
                ),
            )
            return

        # 联盟 SSV 回调无需 Bearer（服务端对服务端）
        if path == "/v1/credits/ad-reward/pangle/callback":
            self._handle_pangle_callback(body)
            return

        if path == "/v1/audit/sync":
            self._handle_audit_sync(body)
            return

        if path == "/v1/audit/async":
            self._handle_audit_async_enqueue(body)
            return

        if path.startswith("/v1/audit/async/") and path.endswith("/complete"):
            job_id = path.removeprefix("/v1/audit/async/").removesuffix("/complete")
            self._handle_audit_async_complete(job_id, body)
            return

        if path == "/v1/appeals":
            self._handle_audit_appeal(body)
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
            self._handle_post_create(body)
            return

        if path == "/v1/families":
            name = body.get("name", "E2E测试家庭")
            self._send(
                200,
                api_response(
                    {"familyId": FAMILY_ID, "name": name, "role": "admin"},
                    "req_mock_family_create",
                ),
            )
            return

        if path.startswith("/v1/families/") and path.endswith("/invitations"):
            self._send(
                200,
                api_response(
                    {
                        "code": INVITE_CODE,
                        "expireAt": "2026-12-31T23:59:59Z",
                        "maxUses": 8,
                        "usedCount": 0,
                        "qrPayload": {
                            "scheme": "baobao://invite",
                            "code": INVITE_CODE,
                            "sig": "mock_sig_e2e",
                        },
                    },
                    "req_mock_invite_create",
                ),
            )
            return

        if path.startswith("/v1/invitations/") and path.endswith("/join"):
            member_id = self._user_id()
            admin = _ensure_credit_user("usr_e2e_admin")
            ref = f"invite_{member_id}"
            if ref not in admin["invite_grants"]:
                _grant_credits(admin, INVITE_CREDITS, "invite", member_id)
                admin["invite_grants"].add(ref)
            self._send(
                200,
                api_response(
                    {
                        "familyId": FAMILY_ID,
                        "role": "family",
                        "joinedAt": "2026-06-06T10:00:00Z",
                    },
                    "req_mock_invite_join",
                ),
            )
            return

        if path.startswith("/v1/families/") and path.endswith("/babies"):
            self._send(
                200,
                api_response(
                    {
                        "babyId": BABY_ID,
                        "familyId": FAMILY_ID,
                        "name": body.get("name", "小测"),
                        "birthday": body.get("birthday", "2024-06-01"),
                        "gender": body.get("gender", "unknown"),
                        "timezone": "Asia/Shanghai",
                        "avatarUrl": None,
                    },
                    "req_mock_baby_create",
                ),
            )
            return

        if path == "/v1/account/logout":
            self._send(200, api_response(request_id="req_mock_logout"))
            return

        if path == "/v1/ai/tasks":
            self._handle_ai_create(body)
            return

        if path.startswith("/v1/ai/tasks/") and path.endswith("/appeal"):
            self._handle_ai_appeal(path, body)
            return

        if path == "/v1/credits/iap-verify":
            self._handle_credits_iap_verify(body)
            return

        if path == "/v1/credits/sign-in":
            self._handle_credits_sign_in()
            return

        if path == "/v1/credits/ad-reward":
            self._handle_credits_ad_reward(body)
            return

        if path == "/v1/subscriptions/iap-verify":
            self._handle_subscription_iap_verify(body)
            return

        if path == "/v1/e2e/subscriptions/event":
            self._handle_e2e_sub_event(body)
            return

        if path == "/v1/account/consents/child-data":
            self._send(
                200,
                api_response(
                    {"version": "child_consent_v1", "agreedAt": "2026-06-06T10:00:00Z"},
                    "req_mock_consent",
                ),
            )
            return

        if path.startswith("/v1/posts/") and path.endswith("/likes") and path.count("/") == 4:
            post_id = path.split("/")[3]
            self._handle_post_like(post_id)
            return

        if path.endswith("/comments") and path.startswith("/v1/posts/") and path.count("/") == 4:
            post_id = path.split("/")[3]
            self._handle_post_comment(post_id, body)
            return

        if path == "/v1/caption/generate":
            self._handle_caption_generate(body)
            return

        if path == "/v1/notifications/devices":
            self._handle_notification_register(body)
            return

        if path == "/v1/notifications/mark-read":
            self._handle_notification_mark_read(body)
            return

        if path == "/v1/e2e/share/wechat":
            self._handle_e2e_share_wechat(body)
            return

        if path == "/v1/e2e/share/system":
            self._handle_e2e_share_system(body)
            return

        if path == "/v1/e2e/feed/ugc-appeal":
            self._handle_e2e_feed_ugc_appeal(body)
            return

        if path == "/v1/e2e/feed/ugc-media-audit":
            self._handle_e2e_feed_ugc_media_audit(body)
            return

        if path == "/v1/backup/providers":
            if not self._auth_ok():
                self._send(401, b'{"code":"UNAUTHORIZED"}')
                return
            self._handle_backup_bind(body)
            return

        if path == "/v1/backup/status":
            if not self._auth_ok():
                self._send(401, b'{"code":"UNAUTHORIZED"}')
                return
            self._handle_backup_report_status(body)
            return

        if path == "/v1/account/export":
            if not self._auth_ok():
                self._send(401, b'{"code":"UNAUTHORIZED"}')
                return
            self._handle_account_export()
            return

        self._send(404, b'{"code":"NOT_FOUND"}')

    def _handle_post_create(self, body: dict) -> None:
        scenario = self.headers.get("X-E2E-Scenario", "")
        user_id = self._user_id()

        # P0 冒烟旧格式兼容（babyId + media）；须写入 POSTS 供 Feed / 点赞联调
        if "media" in body and "items" not in body:
            family_id = str(body.get("familyId", "fam_smoke_001"))
            baby_id = str(body.get("babyId", "bb_smoke_001"))
            post_id = "post_smoke_001"
            created_at = _utc_now_iso()
            caption = body.get("caption", "P0 冒烟发布（mock）")
            media_in = body.get("media", [])
            items_out = []
            for idx, item in enumerate(media_in):
                kind = item.get("kind", "image")
                if kind == "photo":
                    kind = "image"
                items_out.append(
                    {
                        "itemId": f"pit_smoke_{idx + 1}",
                        "kind": kind,
                        "objectKey": item.get("objectKey", ""),
                        "mime": item.get("mime"),
                        "width": item.get("width", 0),
                        "height": item.get("height", 0),
                        "duration": item.get("duration"),
                        "deepSynth": bool(item.get("deepSynth")),
                        "thumbnailKey": item.get("thumbnailKey"),
                    }
                )
            post = {
                "postId": post_id,
                "familyId": family_id,
                "ownerUserId": user_id,
                "babyIds": [baby_id],
                "caption": caption,
                "visibility": "family",
                "status": "published",
                "createdAt": created_at,
                "items": items_out,
            }
            POSTS[post_id] = post
            _push_family_notification(post)
            self._send(
                200,
                api_response(
                    {
                        "postId": post_id,
                        "status": "published",
                        "familyId": family_id,
                        "babyId": baby_id,
                        "media": media_in,
                        "caption": caption,
                        "createdAt": created_at,
                    },
                    "req_mock_post_create",
                ),
            )
            return

        if scenario == "rate_limit":
            status, err = api_error("COMMON_RATE_LIMIT", status_hint=429)
            self._send(status, err)
            return

        caption = str(body.get("caption", ""))
        if _ugc_reject(caption):
            status, err = api_error("POST_AUDIT_REJECTED", "ugc text rejected", 422)
            self._send(status, err)
            return

        now_ts = time.time()
        if scenario != "no_rate_limit":
            times = [t for t in POST_CREATE_TIMES.get(user_id, []) if now_ts - t <= POST_RATE_WINDOW_SEC]
            if len(times) >= POST_RATE_MAX:
                status, err = api_error("COMMON_RATE_LIMIT", status_hint=429)
                self._send(status, err)
                return
            times.append(now_ts)
            POST_CREATE_TIMES[user_id] = times

        family_id = str(body.get("familyId", FAMILY_ID))
        baby_ids = body.get("babyIds") or ([body.get("babyId")] if body.get("babyId") else [BABY_ID])
        visibility = str(body.get("visibility") or "family")
        items_in = body.get("items") or []
        status = "audit" if items_in else "published"
        created_at = _utc_now_iso()
        post_id = _next_post_id()

        items_out = []
        for idx, item in enumerate(items_in):
            kind = item.get("kind", "image")
            if kind == "photo":
                kind = "image"
            items_out.append(
                {
                    "itemId": f"pit_e2e_{post_id[-4:]}_{idx + 1}",
                    "kind": kind,
                    "objectKey": item.get("objectKey", ""),
                    "mime": item.get("mime"),
                    "width": item.get("width", 0),
                    "height": item.get("height", 0),
                    "duration": item.get("duration"),
                    "deepSynth": bool(item.get("deepSynth")),
                    "thumbnailKey": item.get("thumbnailKey"),
                }
            )

        post = {
            "postId": post_id,
            "familyId": family_id,
            "ownerUserId": user_id,
            "babyIds": baby_ids,
            "caption": caption,
            "visibility": visibility,
            "status": status,
            "createdAt": created_at,
            "items": items_out,
        }
        POSTS[post_id] = post
        if visibility == "family" and status in ("published", "audit"):
            _push_family_notification(post)

        self._send(200, api_response({"postId": post_id, "status": status, "createdAt": created_at}, "req_mock_post_create"))

    def _handle_post_delete(self, post_id: str) -> None:
        post = POSTS.get(post_id)
        if not post or post.get("status") == "removed":
            status, err = api_error("COMMON_NOT_FOUND", status_hint=404)
            self._send(status, err)
            return
        if post.get("ownerUserId") != self._user_id():
            status, err = api_error("COMMON_FORBIDDEN", status_hint=403)
            self._send(status, err)
            return
        deleted_at = _utc_now_iso()
        post["status"] = "removed"
        post["deletedAt"] = deleted_at
        self._send(
            200,
            api_response({"postId": post_id, "status": "removed", "deletedAt": deleted_at}, "req_mock_post_delete"),
        )

    def _handle_post_like(self, post_id: str) -> None:
        post = POSTS.get(post_id)
        if not post or post.get("status") == "removed":
            status, err = api_error("COMMON_NOT_FOUND", status_hint=404)
            self._send(status, err)
            return
        user_id = self._user_id()
        key = (post_id, user_id)
        duplicate = key in LIKES
        if not duplicate:
            LIKES.add(key)
        self._send(
            200,
            api_response(
                {
                    "postId": post_id,
                    "userId": user_id,
                    "likedAt": _utc_now_iso(),
                    **({"duplicate": True} if duplicate else {}),
                },
                "req_mock_post_like",
            ),
        )

    def _handle_post_comment(self, post_id: str, body: dict) -> None:
        post = POSTS.get(post_id)
        if not post or post.get("status") == "removed":
            status, err = api_error("COMMON_NOT_FOUND", status_hint=404)
            self._send(status, err)
            return
        text = str(body.get("text", "")).strip()
        if not text:
            status, err = api_error("COMMON_BAD_PARAM", status_hint=400)
            self._send(status, err)
            return
        if _ugc_reject(text):
            status, err = api_error("POST_AUDIT_REJECTED", "ugc text rejected", 422)
            self._send(status, err)
            return
        user_id = self._user_id()
        comment_id = _next_comment_id()
        created_at = _utc_now_iso()
        comment = {
            "commentId": comment_id,
            "postId": post_id,
            "userId": user_id,
            "text": text,
            "createdAt": created_at,
        }
        COMMENTS[comment_id] = comment
        self._send(200, api_response(comment, "req_mock_post_comment"))

    def _handle_caption_generate(self, body: dict) -> None:
        scenario = self.headers.get("X-E2E-Scenario", "")
        user_id = self._user_id()
        if scenario == "caption_limit":
            status, err = api_error("CAPTION_DAILY_LIMIT", status_hint=429)
            self._send(status, err)
            return

        baby_id = str(body.get("babyId", "")).strip()
        if not baby_id or body.get("ageDays") is None:
            status, err = api_error("COMMON_BAD_PARAM", status_hint=400)
            self._send(status, err)
            return

        cache_key = _caption_cache_key(body)
        cached = CAPTION_CACHE.get(cache_key)
        cap_user = _ensure_caption_user(user_id)
        today = _today_utc().isoformat()
        if cap_user["day"] != today:
            cap_user["day"] = today
            cap_user["count"] = 0

        if cached:
            remaining = max(CAPTION_DAILY_LIMIT - cap_user["count"], 0)
            self._send(
                200,
                api_response(
                    {"candidates": cached["candidates"], "remainingToday": remaining},
                    "req_mock_caption_cache",
                ),
            )
            return

        if cap_user["count"] >= CAPTION_DAILY_LIMIT:
            status, err = api_error("CAPTION_DAILY_LIMIT", status_hint=429)
            self._send(status, err)
            return

        candidates = _caption_candidates(body)
        CAPTION_CACHE[cache_key] = {"candidates": candidates}
        cap_user["count"] += 1
        remaining = max(CAPTION_DAILY_LIMIT - cap_user["count"], 0)
        self._send(
            200,
            api_response({"candidates": candidates, "remainingToday": remaining}, "req_mock_caption_generate"),
        )

    def _handle_notification_register(self, body: dict) -> None:
        device_id = str(body.get("deviceId", "")).strip()
        token = str(body.get("apnsToken", "")).strip()
        if not device_id or not token:
            status, err = api_error("COMMON_BAD_PARAM", status_hint=400)
            self._send(status, err)
            return
        region = self.headers.get("X-Region", "cn")
        self._send(
            200,
            api_response(
                {"deviceId": device_id, "apnsToken": token, "region": region},
                "req_mock_notif_register",
            ),
        )

    def _handle_notification_mark_read(self, body: dict) -> None:
        user_id = self._user_id()
        ids = body.get("ids") or []
        mark_all = bool(body.get("all"))
        marked = 0
        items = NOTIFICATIONS.get(user_id, [])
        if mark_all:
            for n in items:
                if not n.get("readAt"):
                    n["readAt"] = _utc_now_iso()
                    marked += 1
        else:
            id_set = set(ids)
            for n in items:
                if n.get("id") in id_set and not n.get("readAt"):
                    n["readAt"] = _utc_now_iso()
                    marked += 1
        unread = sum(1 for n in items if not n.get("readAt"))
        self._send(
            200,
            api_response({"markedCount": marked, "unreadCount": unread}, "req_mock_notif_mark_read"),
        )

    def _handle_e2e_share_wechat(self, body: dict) -> None:
        scene = str(body.get("scene", "timeline")).strip()
        if scene not in ("timeline", "session"):
            status, err = api_error("COMMON_BAD_PARAM", "scene must be timeline|session", 400)
            self._send(status, err)
            return
        caption = str(body.get("caption", ""))
        if not caption.strip():
            status, err = api_error("COMMON_BAD_PARAM", "caption required", 400)
            self._send(status, err)
            return
        if self.headers.get("X-E2E-Scenario") == "wechat_not_installed":
            status, err = api_error("SHARE_WECHAT_NOT_INSTALLED", status_hint=422)
            self._send(status, err)
            return
        deep_synth = bool(body.get("deepSynth", True))
        brand_removable = bool(body.get("brandWatermarkRemovable", False))
        self._send(
            200,
            api_response(
                {
                    "channel": "wechat",
                    "scene": scene,
                    "accepted": True,
                    "thumbnailAdapted": True,
                    "universalLinkValid": True,
                    "deepSynthWatermark": deep_synth,
                    "brandWatermarkApplied": not brand_removable,
                    "title": caption[:32],
                    "description": caption if scene == "timeline" else caption[:64],
                },
                "req_mock_share_wechat",
            ),
        )

    def _handle_e2e_share_system(self, body: dict) -> None:
        caption = str(body.get("caption", "")).strip()
        hashtags = body.get("hashtags") or []
        destination = str(body.get("destination", "generic")).strip()
        if not caption:
            status, err = api_error("COMMON_BAD_PARAM", "caption required", 400)
            self._send(status, err)
            return
        tag_text = " ".join(hashtags) if hashtags else ""
        clipboard = f"{caption}\n{tag_text}".strip()
        self._send(
            200,
            api_response(
                {
                    "channel": "system",
                    "destination": destination,
                    "accepted": True,
                    "clipboardText": clipboard,
                    "usesSystemShareSheet": True,
                    "clipboardHintShown": True,
                },
                "req_mock_share_system",
            ),
        )

    def _handle_audit_sync(self, body: dict) -> None:
        kind = str(body.get("kind") or "").strip().lower()
        target_ref = str(body.get("targetRef") or "").strip()
        region = str(body.get("region") or "").strip().lower()
        if kind not in ("input", "output", "ugc"):
            self._send(400, json.dumps({"error": "invalid kind"}).encode())
            return
        if not target_ref:
            self._send(400, json.dumps({"error": "targetRef required"}).encode())
            return
        if region not in ("cn", "os"):
            self._send(400, json.dumps({"error": "invalid region"}).encode())
            return
        media_type = _audit_media_type(body)
        if kind == "ugc" and media_type in ("image", "video"):
            self._send(400, json.dumps({"error": "ugc media must use async endpoint"}).encode())
            return
        try:
            passed, reasons, vendor = _audit_decision(body)
        except ValueError as exc:
            self._send(400, json.dumps({"error": str(exc)}).encode())
            return
        now = _utc_now_iso()
        status = "passed" if passed else "rejected"
        job_id = _next_audit_job_id()
        job = {
            "jobId": job_id,
            "kind": kind,
            "targetRef": target_ref,
            "status": status,
            "result": status,
            "reasons": reasons,
            "vendor": vendor,
            "region": region,
            "mediaType": media_type,
            "createdAt": now,
            "completedAt": now,
        }
        AUDIT_JOBS[job_id] = job
        self._send(200, json.dumps(_audit_job_dto(job), ensure_ascii=False).encode())

    def _handle_audit_async_enqueue(self, body: dict) -> None:
        kind = str(body.get("kind") or "ugc").strip().lower()
        target_ref = str(body.get("targetRef") or "").strip()
        region = str(body.get("region") or "cn").strip().lower()
        media_type = _audit_media_type(body)
        if kind != "ugc" or media_type not in ("image", "video"):
            self._send(400, json.dumps({"error": "async enqueue requires ugc image/video"}).encode())
            return
        if not target_ref or region not in ("cn", "os"):
            self._send(400, json.dumps({"error": "targetRef and valid region required"}).encode())
            return
        now = _utc_now_iso()
        job_id = _next_audit_job_id()
        job = {
            "jobId": job_id,
            "kind": kind,
            "targetRef": target_ref,
            "status": "pending",
            "result": "pending",
            "reasons": [],
            "vendor": _audit_vendor(region, media_type),
            "region": region,
            "mediaType": media_type,
            "objectKey": body.get("objectKey", ""),
            "createdAt": now,
            "completedAt": None,
        }
        AUDIT_JOBS[job_id] = job
        self._send(200, json.dumps(_audit_job_dto(job), ensure_ascii=False).encode())

    def _handle_audit_async_complete(self, job_id: str, body: dict) -> None:
        job = AUDIT_JOBS.get(job_id)
        if not job:
            self._send(404, json.dumps({"error": "audit job not found"}).encode())
            return
        if job.get("status") != "pending":
            self._send(200, json.dumps(_audit_job_dto(job), ensure_ascii=False).encode())
            return
        merged = {
            "region": body.get("region") or job.get("region", "cn"),
            "mediaType": body.get("mediaType") or job.get("mediaType", ""),
            "objectKey": body.get("objectKey") or job.get("objectKey", ""),
            "targetRef": job.get("targetRef", ""),
            "text": body.get("text", ""),
        }
        try:
            passed, reasons, vendor = _audit_decision(merged)
        except ValueError as exc:
            self._send(400, json.dumps({"error": str(exc)}).encode())
            return
        status = "passed" if passed else "rejected"
        now = _utc_now_iso()
        job.update(
            {
                "status": status,
                "result": status,
                "reasons": reasons,
                "vendor": vendor,
                "completedAt": now,
            }
        )
        AUDIT_JOBS[job_id] = job
        self._send(200, json.dumps(_audit_job_dto(job), ensure_ascii=False).encode())

    def _handle_audit_appeal(self, body: dict) -> None:
        audit_job_id = str(body.get("auditJobId") or "").strip()
        target_ref = str(body.get("targetRef") or "").strip()
        user_id = str(body.get("userId") or "").strip()
        reason = str(body.get("reason") or "").strip()
        if not reason or not user_id:
            self._send(400, json.dumps({"error": "userId and reason required"}).encode())
            return
        job = None
        if audit_job_id:
            job = AUDIT_JOBS.get(audit_job_id)
        elif target_ref:
            for candidate in reversed(list(AUDIT_JOBS.values())):
                if candidate.get("targetRef") == target_ref and candidate.get("status") == "rejected":
                    job = candidate
                    audit_job_id = candidate["jobId"]
                    break
        if not job:
            self._send(404, json.dumps({"error": "audit job not found"}).encode())
            return
        if job.get("status") != "rejected":
            self._send(409, json.dumps({"error": "appeal not allowed"}).encode())
            return
        for appeal in AUDIT_APPEALS.values():
            if appeal.get("auditJobId") == audit_job_id:
                self._send(409, json.dumps({"error": "appeal duplicate"}).encode())
                return
        appeal_id = _next_audit_appeal_id()
        record = {
            "appealId": appeal_id,
            "auditJobId": audit_job_id,
            "targetRef": job.get("targetRef", ""),
            "userId": user_id,
            "reason": reason,
            "status": "pending",
            "submittedAt": _utc_now_iso(),
            "slaHours": 24,
        }
        AUDIT_APPEALS[appeal_id] = record
        self._send(201, json.dumps({"appealId": appeal_id, "status": "pending"}, ensure_ascii=False).encode())

    def _handle_e2e_feed_ugc_media_audit(self, body: dict) -> None:
        post_id = str(body.get("postId") or "").strip()
        if not post_id:
            status, err = api_error("COMMON_BAD_PARAM", status_hint=400)
            self._send(status, err)
            return
        post = POSTS.get(post_id)
        if not post or post.get("status") == "removed":
            status, err = api_error("COMMON_NOT_FOUND", status_hint=404)
            self._send(status, err)
            return
        region = str(self.headers.get("X-Region", "cn")).strip().lower()
        rejected = False
        reasons: list[str] = []
        for item in post.get("items") or []:
            merged = {
                "region": region,
                "mediaType": item.get("kind", "image"),
                "objectKey": item.get("objectKey", ""),
                "targetRef": post_id,
                "text": "",
            }
            passed, item_reasons, _vendor = _audit_decision(merged)
            if not passed:
                rejected = True
                reasons.extend(item_reasons)
        if rejected:
            post["status"] = "removed"
            post["auditResult"] = "rejected"
            post["auditReasons"] = reasons
        else:
            post["status"] = "published"
            post["auditResult"] = "passed"
        POSTS[post_id] = post
        self._send(
            200,
            api_response(
                {
                    "postId": post_id,
                    "status": post["status"],
                    "auditResult": post.get("auditResult"),
                    "auditReasons": post.get("auditReasons") or [],
                },
                "req_mock_feed_ugc_media_audit",
            ),
        )

    def _handle_e2e_feed_ugc_appeal(self, body: dict) -> None:
        target_kind = str(body.get("targetKind", "")).strip()
        target_id = str(body.get("targetId", "")).strip()
        reason = str(body.get("reason", "")).strip()
        if target_kind not in ("post", "comment") or not target_id or not reason:
            status, err = api_error("COMMON_BAD_PARAM", status_hint=400)
            self._send(status, err)
            return
        appeal_id = f"apl_feed_{len(UGC_APPEALS) + 1:04d}"
        record = {
            "appealId": appeal_id,
            "targetKind": target_kind,
            "targetId": target_id,
            "status": "pending",
            "reason": reason,
            "submittedAt": _utc_now_iso(),
        }
        UGC_APPEALS[appeal_id] = record
        self._send(200, api_response(record, "req_mock_feed_ugc_appeal"))

    def _handle_backup_bind(self, body: dict) -> None:
        kind = str(body.get("kind", "")).strip()
        if not _valid_backup_kind(kind):
            status, err = api_error("BACKUP_INVALID_PROVIDER", status_hint=400)
            self._send(status, err)
            return
        if kind == "baidu_pan" and not str(body.get("accessToken", "")).strip():
            status, err = api_error("COMMON_BAD_PARAM", "access token required for baidu_pan", 400)
            self._send(status, err)
            return

        user_id = self._user_id()
        providers = _user_backup_providers(user_id)
        now = _utc_now_iso()
        existing_id = None
        for pid, provider in providers.items():
            if provider.get("kind") == kind:
                existing_id = pid
                break

        provider_id = existing_id or _next_backup_provider_id()
        provider = {
            "id": provider_id,
            "kind": kind,
            "status": "active",
            "providerAccountId": body.get("providerAccountId"),
            "expiresAt": body.get("expiresAt"),
            "metadata": body.get("metadata") or {},
            "createdAt": providers.get(provider_id, {}).get("createdAt", now),
            "updatedAt": now,
        }
        providers[provider_id] = provider
        self._send(200, api_response(_backup_provider_dto(provider), "req_mock_backup_bind"))

    def _handle_backup_list(self) -> None:
        user_id = self._user_id()
        items = [_backup_provider_dto(p) for p in _user_backup_providers(user_id).values()]
        items.sort(key=lambda item: item.get("createdAt", ""))
        self._send(200, api_response({"items": items}, "req_mock_backup_list"))

    def _handle_backup_unbind(self, provider_id: str) -> None:
        user_id = self._user_id()
        providers = _user_backup_providers(user_id)
        if provider_id not in providers:
            status, err = api_error("COMMON_NOT_FOUND", status_hint=404)
            self._send(status, err)
            return
        del providers[provider_id]
        self._send(200, api_response({"id": provider_id}, "req_mock_backup_unbind"))

    def _handle_backup_get_status(self) -> None:
        user_id = self._user_id()
        self._send(200, api_response(_backup_status_dto(user_id), "req_mock_backup_status_get"))

    def _handle_backup_report_status(self, body: dict) -> None:
        user_id = self._user_id()
        success = bool(body.get("success"))
        attempted_at = str(body.get("attemptedAt") or _utc_now_iso())
        error_code = body.get("errorCode")
        status = BACKUP_STATUS.setdefault(user_id, {"failureCount": 0})

        status["lastAttemptAt"] = attempted_at
        if success:
            status["lastSuccessAt"] = attempted_at
            status["failureCount"] = 0
            status["lastErrorCode"] = None
        else:
            status["failureCount"] = int(status.get("failureCount", 0)) + 1
            status["lastErrorCode"] = error_code or "BACKUP_UNKNOWN"
        self._send(200, api_response(_backup_status_dto(user_id), "req_mock_backup_status_report"))

    def _handle_account_export(self) -> None:
        user_id = self._user_id()
        now = _utc_now_iso()
        existing = ACCOUNT_EXPORTS.get(user_id)
        if existing:
            self._send(202, api_response(existing, "req_mock_account_export"))
            return
        export_id = f"exp_e2e_{len(ACCOUNT_EXPORTS) + 1:04d}"
        record = {
            "exportId": export_id,
            "status": "queued",
            "requestedAt": now,
        }
        ACCOUNT_EXPORTS[user_id] = record
        self._send(202, api_response(record, "req_mock_account_export"))

    def _handle_credits_iap_verify(self, body: dict) -> None:
        user = _ensure_credit_user(self._user_id())
        tx_id = str(body.get("transactionId", "")).strip()
        product_id = str(body.get("productId", "")).strip()
        credits = IAP_PRODUCT_CREDITS.get(product_id, 0)
        if not tx_id or not product_id or credits <= 0:
            status, err = api_error("IAP_VERIFY_FAILED", status_hint=400)
            self._send(status, err)
            return
        if tx_id in user["iap_txs"]:
            self._send(
                200,
                api_response(
                    {
                        "grantedCredits": 0,
                        "balanceAfter": user["balance"],
                        "transactionId": tx_id,
                        "ledgerId": "",
                        "duplicate": True,
                    },
                    "req_mock_iap_dup",
                ),
            )
            return
        user["iap_txs"].add(tx_id)
        granted, ledger_id = _grant_credits(user, credits, "iap", tx_id)
        self._send(
            200,
            api_response(
                {
                    "grantedCredits": granted,
                    "balanceAfter": user["balance"],
                    "transactionId": tx_id,
                    "ledgerId": ledger_id,
                },
                "req_mock_iap_verify",
            ),
        )

    def _handle_credits_sign_in(self) -> None:
        user = _ensure_credit_user(self._user_id())
        today = _today_utc()
        if user["sign_in_date"] == today:
            status, err = api_error("CREDIT_SIGN_IN_DONE", status_hint=409)
            self._send(status, err)
            return
        streak = user["streak"] + 1 if user["sign_in_date"] else 1
        granted = min(5 + (streak - 1) * 2, 20)
        user["sign_in_date"] = today
        user["streak"] = streak
        _, ledger_id = _grant_credits(user, granted, "sign_in", today.isoformat())
        self._send(
            200,
            api_response(
                {
                    "grantedCredits": granted,
                    "balanceAfter": user["balance"],
                    "streak": streak,
                    "ledgerId": ledger_id,
                },
                "req_mock_sign_in",
            ),
        )

    def _handle_credits_ad_reward(self, body: dict) -> None:
        user = _ensure_credit_user(self._user_id())
        trans_id = str(body.get("transId", "")).strip()
        nonce = self.headers.get("X-Nonce", "")
        ts = self.headers.get("X-Timestamp", "")
        if not trans_id or not nonce or not ts:
            status, err = api_error("COMMON_BAD_PARAM", status_hint=400)
            self._send(status, err)
            return
        if trans_id in user["ad_trans"]:
            self._send(
                200,
                api_response(
                    {
                        "grantedCredits": 0,
                        "balanceAfter": user["balance"],
                        "ledgerId": "",
                        "duplicate": True,
                    },
                    "req_mock_ad_dup",
                ),
            )
            return
        if user["ad_today"] >= AD_DAILY_LIMIT:
            status, err = api_error("CREDIT_AD_DAILY_LIMIT", status_hint=429)
            self._send(status, err)
            return
        user["ad_trans"].add(trans_id)
        user["ad_today"] += 1
        granted, ledger_id = _grant_credits(user, AD_REWARD_CREDITS, "ad_reward", trans_id)
        self._send(
            200,
            api_response(
                {
                    "grantedCredits": granted,
                    "balanceAfter": user["balance"],
                    "ledgerId": ledger_id,
                },
                "req_mock_ad_reward",
            ),
        )

    def _handle_pangle_callback(self, body: dict) -> None:
        user_id = str(body.get("user_id", "")).strip()
        trans_id = str(body.get("trans_id", "")).strip()
        sign = str(body.get("sign", "")).strip()
        expected = hmac.new(
            PANGLE_MOCK_SECRET.encode(),
            f"{trans_id}:{user_id}".encode(),
            hashlib.sha256,
        ).hexdigest()
        if sign != expected:
            status, err = api_error("CREDIT_AD_SIGNATURE_INVALID", status_hint=403)
            self._send(status, err)
            return
        user = _ensure_credit_user(user_id or "usr_e2e_admin")
        if trans_id in user["ad_trans"]:
            self._send(
                200,
                api_response(
                    {"grantedCredits": 0, "balanceAfter": user["balance"], "duplicate": True},
                    "req_mock_pangle_dup",
                ),
            )
            return
        user["ad_trans"].add(trans_id)
        user["ad_today"] += 1
        granted, ledger_id = _grant_credits(user, AD_REWARD_CREDITS, "ad_reward", trans_id)
        self._send(
            200,
            api_response(
                {"grantedCredits": granted, "balanceAfter": user["balance"], "ledgerId": ledger_id},
                "req_mock_pangle_cb",
            ),
        )

    def _handle_subscription_iap_verify(self, body: dict) -> None:
        user = _ensure_credit_user(self._user_id())
        tx_id = str(body.get("transactionId", "")).strip()
        product_id = str(body.get("productId", "com.baobao.sub.monthly")).strip()
        if not tx_id:
            status, err = api_error("IAP_VERIFY_FAILED", status_hint=400)
            self._send(status, err)
            return
        dup_key = f"sub_{tx_id}"
        existing = user.get("subscription")
        if user.get("sub_tx") == dup_key and existing:
            self._send(
                200,
                api_response({**existing, "duplicate": True}, "req_mock_sub_iap_dup"),
            )
            return
        user["sub_tx"] = dup_key
        sub_id = f"sub_{self._user_id()[:8]}"
        now = datetime.now(timezone.utc)
        period_end = now.replace(month=now.month + 1 if now.month < 12 else 1, year=now.year + (1 if now.month == 12 else 0))
        sub = {
            "subscriptionId": sub_id,
            "state": "active",
            "sku": product_id,
            "periodStart": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "periodEnd": period_end.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "autoRenew": True,
            "entitlements": ENTITLEMENTS_ACTIVE,
        }
        user["subscription"] = sub
        self._send(200, api_response(sub, "req_mock_sub_iap_verify"))

    def _handle_e2e_sub_event(self, body: dict) -> None:
        """Mock-only：模拟订阅 grace / refund / expire（T4.17）。"""
        if not self._auth_ok():
            self._send(401, b'{"code":"UNAUTHORIZED"}')
            return
        user = _ensure_credit_user(self._user_id())
        event = str(body.get("event", "")).strip()
        sub = user.get("subscription")
        if not sub:
            status, err = api_error("COMMON_BAD_PARAM", "no subscription", 400)
            self._send(status, err)
            return
        if event == "grace":
            sub["state"] = "grace"
        elif event == "refund":
            sub["state"] = "refunded"
            sub["entitlements"] = ENTITLEMENTS_NONE
        elif event == "expire":
            sub["state"] = "expired"
            sub["entitlements"] = ENTITLEMENTS_NONE
        else:
            status, err = api_error("COMMON_BAD_PARAM", status_hint=400)
            self._send(status, err)
            return
        user["subscription"] = sub
        self._send(200, api_response({"state": sub["state"], "entitlements": sub.get("entitlements", ENTITLEMENTS_NONE)}, "req_mock_sub_event"))

    def _ai_hold_credits(self, user_id: str, cost: int, task_id: str) -> int:
        user = _ensure_credit_user(user_id)
        user["balance"] -= cost
        _append_ledger(user, "charge", -cost, "ai_hold", task_id)
        return user["balance"]

    def _ai_release_credits(self, user_id: str, cost: int, task_id: str) -> int:
        user = _ensure_credit_user(user_id)
        user["balance"] += cost
        _append_ledger(user, "refund", cost, "ai_release", task_id)
        return user["balance"]

    def _handle_ai_create(self, body: dict) -> None:
        scenario = self.headers.get("X-E2E-Scenario", "")
        network = self.headers.get("X-E2E-Network", "")
        play = body.get("play", "ghibli_kid")
        params = body.get("params") or {}
        duration = int(params.get("duration") or 0)
        user_id = self._user_id()

        if scenario == "model_failed":
            task_id = "tsk_e2e_model_failed"
            terminal = "failed"
            cost, eta = 8, 18
        elif scenario == "rejected":
            task_id = "tsk_e2e_rejected"
            terminal = "rejected"
            cost, eta = 8, 18
        elif scenario == "background":
            task_id = "tsk_e2e_background"
            terminal = "succeeded"
            cost, eta = 8, 18
        elif network == "slow":
            task_id = "tsk_e2e_slow_net"
            terminal = "succeeded"
            cost, eta = 8, 45
        elif play == "video_walk" and duration == 5:
            task_id = "tsk_e2e_vid_5s"
            terminal = "succeeded"
            cost, eta = 60, 120
        elif play == "video_walk" and duration == 10:
            task_id = "tsk_e2e_vid_10s"
            terminal = "succeeded"
            cost, eta = 120, 240
        elif scenario == "insufficient_balance":
            task_id = "tsk_e2e_negative_bal"
            terminal = "succeeded"
            cost, eta = 200, 18
        else:
            task_id = "tsk_e2e_img_happy"
            terminal = "succeeded"
            cost, eta = 8, 18

        balance = self._ai_hold_credits(user_id, cost, task_id)

        AI_TASKS[task_id] = {
            "terminal": terminal,
            "polls": 0,
            "play": play,
            "duration": duration,
            "cost": cost,
            "balance": balance,
            "slow": network == "slow",
            "user_id": user_id,
            "refunded": False,
        }
        initial = "running" if scenario == "background" else "credit_held"
        self._send(
            200,
            api_response(
                {
                    "taskId": task_id,
                    "play": play,
                    "state": initial,
                    "costCredits": cost,
                    "balanceAfter": balance,
                    "estimatedSeconds": eta,
                },
                f"req_mock_ai_create_{task_id}",
            ),
        )

    def _handle_ai_appeal(self, path: str, body: dict) -> None:
        task_id = path.removeprefix("/v1/ai/tasks/").removesuffix("/appeal")
        reason = (body.get("reason") or "").strip()
        if not reason:
            self._send(400, b'{"code":"COMMON_BAD_PARAM","message":"reason required"}')
            return
        task = AI_TASKS.get(task_id) or {"terminal": "rejected"}
        if task.get("terminal") != "rejected" and task_id != "tsk_e2e_rejected":
            self._send(409, b'{"code":"AI_APPEAL_NOT_ALLOWED"}')
            return
        AI_TASKS[task_id] = {**task, "terminal": "appealed", "polls": task.get("polls", 0)}
        self._send(
            200,
            api_response(
                {"taskId": task_id, "state": "appealed", "appealId": "apl_e2e_001"},
                "req_mock_ai_appeal",
            ),
        )

    def _ai_task_detail(self, task_id: str) -> dict:
        task = AI_TASKS.get(task_id)
        if task is None:
            fixed = {
                "tsk_e2e_img_happy": ("succeeded", 8, ".heic"),
                "tsk_e2e_model_failed": ("failed", 8, None),
                "tsk_e2e_rejected": ("rejected", 8, None),
                "tsk_e2e_vid_5s": ("succeeded", 60, ".mp4"),
                "tsk_e2e_vid_10s": ("succeeded", 120, ".mp4"),
                "tsk_e2e_background": ("succeeded", 8, ".heic"),
                "tsk_e2e_negative_bal": ("succeeded", 200, ".heic"),
            }
            if task_id in fixed:
                terminal, cost, ext = fixed[task_id]
                task = {"terminal": terminal, "polls": 99, "cost": cost, "ext": ext, "user_id": "usr_e2e_admin", "refunded": terminal == "failed"}
            else:
                return {"taskId": task_id, "state": "running"}

        task["polls"] = task.get("polls", 0) + 1
        polls = task["polls"]
        terminal = task["terminal"]
        cost = task.get("cost", 8)
        user_id = task.get("user_id", "usr_e2e_admin")
        user = _ensure_credit_user(user_id)
        balance = user["balance"]

        if terminal == "appealed":
            return {"taskId": task_id, "state": "appealed", "costCredits": cost, "balanceAfter": balance}

        if task.get("slow") and polls < 3:
            return {"taskId": task_id, "state": "running", "costCredits": cost, "balanceAfter": balance}
        if terminal == "succeeded" and polls < 2 and not task.get("slow"):
            return {"taskId": task_id, "state": "running", "costCredits": cost, "balanceAfter": balance}

        if terminal == "failed" and not task.get("refunded"):
            balance = self._ai_release_credits(user_id, cost, task_id)
            task["refunded"] = True
            task["balance"] = balance
            return {
                "taskId": task_id,
                "state": "failed",
                "failureReason": "模型服务暂时不可用，已自动退还积分",
                "costCredits": cost,
                "balanceAfter": balance,
            }
        if terminal == "rejected":
            if not task.get("refunded"):
                balance = self._ai_release_credits(user_id, cost, task_id)
                task["refunded"] = True
            return {
                "taskId": task_id,
                "state": "rejected",
                "failureReason": "该内容不符合社区规范",
                "costCredits": cost,
                "balanceAfter": balance,
            }

        ext = task.get("ext") or (".mp4" if "vid" in task_id else ".heic")
        return {
            "taskId": task_id,
            "state": "succeeded",
            "resultUrl": f"http://localhost:{PORT}/mock-ai/result/{task_id}{ext}",
            "thumbnailUrl": f"http://localhost:{PORT}/mock-ai/result/{task_id}-thumb.jpg",
            "deepSynth": {"watermark": "v1", "manifest": "c2pa-v1"},
            "costCredits": cost,
            "balanceAfter": balance,
        }


def main() -> None:
    server = HTTPServer(("0.0.0.0", PORT), Handler)
    print(f"[mock-api] fallback listening on http://localhost:{PORT}")
    server.serve_forever()


if __name__ == "__main__":
    main()
