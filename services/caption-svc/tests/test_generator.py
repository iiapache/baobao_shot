from app.models.schemas import CaptionGenerateRequest
from app.services.generator import build_cache_key, generate_stub_candidates


def test_generate_stub_candidates_count():
    req = CaptionGenerateRequest(
        babyId="bb_01HZ",
        ageDays=100,
        play="ghibli_kid",
        location="杭州",
    )
    candidates = generate_stub_candidates(req)
    assert len(candidates) == 3
    assert all(candidate.text for candidate in candidates)


def test_build_cache_key_stable():
    req = CaptionGenerateRequest(babyId="bb_x", ageDays=1, play="ghibli_kid")
    assert build_cache_key(req) == build_cache_key(req)


def test_build_cache_key_changes_with_input():
    base = CaptionGenerateRequest(babyId="bb_x", ageDays=1)
    other = CaptionGenerateRequest(babyId="bb_y", ageDays=1)
    assert build_cache_key(base) != build_cache_key(other)
