import hashlib
import json

from app.config import settings
from app.models.schemas import CaptionCandidate, CaptionGenerateRequest

PLAY_LABELS = {
    "ghibli_kid": "吉卜力小主角",
    "cartoon": "卡通版",
    "watercolor": "水彩风",
    "storybook": "绘本风",
}


def _baby_label(baby_id: str) -> str:
    suffix = baby_id.rsplit("_", 1)[-1]
    if suffix and suffix != baby_id:
        return f"宝宝{suffix[:4]}"
    return "宝宝"


def _play_label(play: str | None) -> str:
    if not play:
        return "成长瞬间"
    return PLAY_LABELS.get(play, play.replace("_", " "))


def generate_stub_candidates(req: CaptionGenerateRequest) -> list[CaptionCandidate]:
    baby = _baby_label(req.baby_id)
    play = _play_label(req.play)
    location = req.location or "今天"
    age = req.age_days
    model_hint = "通义千问 Turbo" if settings.region == "cn" else "GPT-4o-mini"

    return [
        CaptionCandidate(
            text=f"{baby} · 第 {age} 天 · 化身{play} 🌿",
            hashtags=["#宝宝成长", f"#{play}"],
        ),
        CaptionCandidate(
            text=f"{location}的小晴天里，第 {age} 天的{baby} ✨",
            hashtags=["#日常打卡"],
        ),
        CaptionCandidate(
            text=f"AI 帮我画了一个童话版的{baby}（{model_hint}）💫",
            hashtags=["#AI共创"],
        ),
    ]


def build_cache_key(req: CaptionGenerateRequest) -> str:
    payload = {
        "babyId": req.baby_id,
        "ageDays": req.age_days,
        "play": req.play or "",
        "location": req.location or "",
        "region": settings.region,
    }
    digest = hashlib.sha256(
        json.dumps(payload, sort_keys=True, ensure_ascii=False).encode("utf-8")
    ).hexdigest()
    return digest
