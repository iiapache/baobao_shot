#!/usr/bin/env bash
# T7.17 国际化回归：扫描 Swift 用户可见硬编码中文
# 用法: ./scripts/verify-i18n.sh [--strict]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

STRICT=0
if [[ "${1:-}" == "--strict" ]]; then
  STRICT=1
fi

IOS_DIR="$ROOT/ios"
XCSTRINGS="$ROOT/ios/BabyCamera/Resources/Localizable.xcstrings"
REPORT_DIR="$ROOT/docs/qa/reports"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
REPORT_FILE="$REPORT_DIR/i18n-regression-${TIMESTAMP}.md"

SCOPE_DIRS=(
  "Packages/BabyCameraSettings/Sources"
  "Packages/BabyCameraAccount/Sources"
  "Packages/BabyCameraOnboarding/Sources"
)

mkdir -p "$REPORT_DIR"

log() { echo ">>> $*"; }
fail() { echo "[FAIL] $*" >&2; }
pass() { echo "[PASS] $*"; }
warn() { echo "[WARN] $*" >&2; }

if [[ ! -f "$XCSTRINGS" ]]; then
  fail "Missing Localizable.xcstrings at $XCSTRINGS"
  exit 1
fi

KEY_COUNT=$(python3 - "$XCSTRINGS" <<'PY'
import json, sys
from pathlib import Path
data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
print(len(data.get("strings", {})))
PY
)

log "Localizable.xcstrings keys: $KEY_COUNT"

TMP="$(mktemp)"
SCOPE_TMP="$(mktemp)"
trap 'rm -f "$TMP" "$SCOPE_TMP"' EXIT

python3 - <<'PY' "$IOS_DIR" "$TMP" "$SCOPE_TMP"
import re
import sys
from pathlib import Path

ios_dir = Path(sys.argv[1])
out_all = Path(sys.argv[2])
out_scope = Path(sys.argv[3])

scope_prefixes = (
    "Packages/BabyCameraSettings/Sources/",
    "Packages/BabyCameraAccount/Sources/",
    "Packages/BabyCameraOnboarding/Sources/",
)

cjk = re.compile(r"[\u4e00-\u9fff]")
string_lit = re.compile(r'"(?:\\.|[^"\\])*"')
line_comment = re.compile(r"//.*")
block_comment_start = re.compile(r"/\*")
block_comment_end = re.compile(r"\*/")

skip_path_parts = {"/Tests/", "/Previews/", "PreviewProvider", "Mock", "P2E2E", "P6E2E", "UITest"}


def strip_comments_and_strings(line: str, in_block: bool) -> tuple[str, bool]:
    if in_block:
        end = block_comment_end.search(line)
        if end:
            line = line[end.end():]
            in_block = False
        else:
            return "", True

    while True:
        if in_block:
            end = block_comment_end.search(line)
            if not end:
                return "", True
            line = line[end.end():]
            in_block = False
            continue

        start = block_comment_start.search(line)
        if start:
            before = line[: start.start()]
            end = block_comment_end.search(line, start.end())
            if end:
                line = before + line[end.end():]
                continue
            line = before
            in_block = True
            break

        m = line_comment.search(line)
        if m:
            line = line[: m.start()]
        break

    return line, in_block


def line_has_chinese_string(line: str) -> bool:
    for match in string_lit.finditer(line):
        literal = match.group(0)
        if cjk.search(literal):
            return True
    return False


def should_skip(path: Path) -> bool:
    s = str(path)
    if not s.endswith(".swift"):
        return True
    return any(part in s for part in skip_path_parts)


all_hits: list[tuple[str, int, str]] = []
scope_hits: list[tuple[str, int, str]] = []

for path in sorted(ios_dir.rglob("*.swift")):
    if should_skip(path):
        continue
    rel = path.relative_to(ios_dir).as_posix()
    in_block = False
    in_preview = False
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        continue

    for idx, raw in enumerate(lines, start=1):
        stripped = raw.strip()
        if stripped.startswith("#Preview"):
            in_preview = True
        if in_preview:
            if stripped == "}" and "Preview" in raw:
                in_preview = False
            continue

        code, in_block = strip_comments_and_strings(raw, in_block)
        if in_block:
            continue
        if not code.strip():
            continue
        if not line_has_chinese_string(code):
            continue

        hit = (rel, idx, raw.strip())
        all_hits.append(hit)
        if rel.startswith(scope_prefixes):
            scope_hits.append(hit)

out_all.write_text("\n".join(f"{p}:{l}:{t}" for p, l, t in all_hits))
out_scope.write_text("\n".join(f"{p}:{l}:{t}" for p, l, t in scope_hits))
print(len(all_hits))
print(len(scope_hits))
PY

ALL_COUNT=$(wc -l < "$TMP" | tr -d ' ')
SCOPE_COUNT=$(wc -l < "$SCOPE_TMP" | tr -d ' ')

echo "═══════════════════════════════════════════════════"
echo " T7.17 i18n Hardcoded Chinese Verification"
echo "═══════════════════════════════════════════════════"
echo "Scope (Settings/Login/Onboarding Sources): $SCOPE_COUNT"
echo "All ios (excl. Tests/Preview/E2E):         $ALL_COUNT"
echo ""

{
  echo "# i18n 硬编码中文扫描报告"
  echo ""
  echo "| 字段 | 值 |"
  echo "| --- | --- |"
  echo "| 时间 | $(date '+%Y-%m-%d %H:%M:%S') |"
  echo "| xcstrings keys | $KEY_COUNT |"
  echo "| 范围违规 (Settings/Login/Onboarding) | $SCOPE_COUNT |"
  echo "| 全局违规 (排除 Tests/Preview) | $ALL_COUNT |"
  echo ""
  echo "## 范围违规明细 (Settings / Login / Onboarding)"
  echo ""
  if [[ "$SCOPE_COUNT" -eq 0 ]]; then
    echo "_无违规_"
  else
    echo '```'
    cat "$SCOPE_TMP"
    echo '```'
  fi
  echo ""
  echo "## 全局违规摘要 (前 50 条)"
  echo ""
  if [[ "$ALL_COUNT" -eq 0 ]]; then
    echo "_无违规_"
  else
    echo '```'
    head -50 "$TMP"
    echo '```'
    if [[ "$ALL_COUNT" -gt 50 ]]; then
      echo ""
      echo "_… 另有 $((ALL_COUNT - 50)) 条，见完整扫描输出_"
    fi
  fi
} > "$REPORT_FILE"

log "Report: $REPORT_FILE"

if [[ "$SCOPE_COUNT" -eq 0 ]]; then
  pass "Settings / Login / Onboarding 无硬编码中文"
else
  fail "Settings / Login / Onboarding 仍有 $SCOPE_COUNT 处硬编码中文"
  head -20 "$SCOPE_TMP" >&2
  exit 1
fi

if [[ "$STRICT" -eq 1 && "$ALL_COUNT" -gt 0 ]]; then
  fail "--strict: 全局仍有 $ALL_COUNT 处硬编码中文"
  exit 1
fi

if [[ "$ALL_COUNT" -gt 0 ]]; then
  warn "全局仍有 $ALL_COUNT 处硬编码中文（非范围模块，后续迭代）"
fi

pass "i18n scope verification complete"
exit 0
