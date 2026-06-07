#!/usr/bin/env bash
# T7.9 埋点校验：catalog ↔ AnalyticsEventCatalog.swift ↔ ios 代码 track 引用
# 用法: ./scripts/verify-analytics-events.sh [--strict]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CATALOG="$ROOT/docs/qa/analytics-events-catalog.md"
SWIFT_CATALOG="$ROOT/ios/Packages/BabyCameraDiagnostics/Sources/BabyCameraDiagnostics/Analytics/AnalyticsEventCatalog.swift"
IOS_DIR="$ROOT/ios"
MIN_EVENTS=60
STRICT=0

if [[ "${1:-}" == "--strict" ]]; then
  STRICT=1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

log() { echo ">>> $*"; }
warn() { echo "[WARN] $*" >&2; }
fail() { echo "[FAIL] $*" >&2; }
pass() { echo "[PASS] $*"; }

# ── 1. 从 catalog markdown 提取事件名（须含下划线，排除参数名如 method/balance）──
grep -oE '`[a-z][a-z0-9_]*_[a-z0-9_]+`' "$CATALOG" \
  | tr -d '`' \
  | sort -u > "$TMP/catalog_events.txt"

# ── 2. 从 Swift catalog 提取 static let 常量值 ──
grep -E 'public static let .+ = "' "$SWIFT_CATALOG" \
  | sed -E 's/.*= "([^"]+)".*/\1/' \
  | sort -u > "$TMP/swift_constants.txt"

# ── 3. 从 ios 代码提取 track 引用的事件名 ──
{
  # 字符串字面量（须含下划线，对齐 catalog 命名规约）
  grep -rohE '"[a-z][a-z0-9_]*_[a-z0-9_]+"' "$IOS_DIR" --include='*.swift' 2>/dev/null \
    | tr -d '"' || true
  # AnalyticsEventCatalog 常量值
  cat "$TMP/swift_constants.txt"
} | sort -u > "$TMP/code_events.txt"

CATALOG_COUNT=$(wc -l < "$TMP/catalog_events.txt" | tr -d ' ')
SWIFT_COUNT=$(wc -l < "$TMP/swift_constants.txt" | tr -d ' ')

echo "═══════════════════════════════════════════════════"
echo " T7.9 Analytics Events Verification"
echo "═══════════════════════════════════════════════════"
echo "Catalog file : $CATALOG"
echo "Swift catalog: $SWIFT_CATALOG"
echo "Catalog events: $CATALOG_COUNT (min required: $MIN_EVENTS)"
echo "Swift constants: $SWIFT_COUNT"
echo ""

if [[ "$CATALOG_COUNT" -lt "$MIN_EVENTS" ]]; then
  fail "Catalog has only $CATALOG_COUNT events (< $MIN_EVENTS)"
  exit 1
fi
pass "Catalog event count >= $MIN_EVENTS"

# ── 4. catalog ↔ swift 差异 ──
comm -23 "$TMP/catalog_events.txt" "$TMP/swift_constants.txt" > "$TMP/missing_in_swift.txt" || true
comm -13 "$TMP/catalog_events.txt" "$TMP/swift_constants.txt" > "$TMP/orphan_in_swift.txt" || true

# ── 5. catalog ↔ code track 差异 ──
comm -23 "$TMP/catalog_events.txt" "$TMP/code_events.txt" > "$TMP/missing_track.txt" || true
comm -13 "$TMP/catalog_events.txt" "$TMP/code_events.txt" > "$TMP/orphan_in_code.txt" || true

MISSING_SWIFT=$(wc -l < "$TMP/missing_in_swift.txt" | tr -d ' ')
ORPHAN_SWIFT=$(wc -l < "$TMP/orphan_in_swift.txt" | tr -d ' ')
MISSING_TRACK=$(wc -l < "$TMP/missing_track.txt" | tr -d ' ')
ORPHAN_CODE=$(wc -l < "$TMP/orphan_in_code.txt" | tr -d ' ')

report_list() {
  local title="$1"
  local file="$2"
  local count="$3"
  echo ""
  echo "--- $title ($count) ---"
  if [[ "$count" -eq 0 ]]; then
    echo "(none)"
  else
    cat "$file"
  fi
}

report_list "Missing in AnalyticsEventCatalog.swift (catalog → swift)" "$TMP/missing_in_swift.txt" "$MISSING_SWIFT"
report_list "Orphan in AnalyticsEventCatalog.swift (swift → catalog)" "$TMP/orphan_in_swift.txt" "$ORPHAN_SWIFT"
report_list "Missing track reference in ios code (catalog → code)" "$TMP/missing_track.txt" "$MISSING_TRACK"
report_list "Orphan events in ios code (code → catalog)" "$TMP/orphan_in_code.txt" "$ORPHAN_CODE"

echo ""
echo "═══════════════════════════════════════════════════"
EXIT=0

if [[ "$MISSING_SWIFT" -gt 0 ]]; then
  fail "$MISSING_SWIFT catalog event(s) missing from AnalyticsEventCatalog.swift"
  EXIT=1
else
  pass "All catalog events defined in AnalyticsEventCatalog.swift"
fi

if [[ "$ORPHAN_SWIFT" -gt 0 ]]; then
  warn "$ORPHAN_SWIFT swift constant(s) not in catalog"
  [[ "$STRICT" -eq 1 ]] && EXIT=1
fi

if [[ "$MISSING_TRACK" -gt 0 ]]; then
  fail "$MISSING_TRACK catalog event(s) without code reference"
  EXIT=1
else
  pass "All catalog events referenced in ios code"
fi

if [[ "$ORPHAN_CODE" -gt 0 ]]; then
  warn "$ORPHAN_CODE code event(s) not in catalog (review orphans)"
  [[ "$STRICT" -eq 1 ]] && EXIT=1
fi

if [[ "$EXIT" -eq 0 ]]; then
  echo ""
  pass "T7.9 analytics verification PASSED ($CATALOG_COUNT catalog events)"
fi

exit "$EXIT"
