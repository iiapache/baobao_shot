#!/usr/bin/env bash
# P0 集成冒烟：聚合本地可执行验证（无需 K8s / Xcode 集群）
# 用法: ./scripts/p0-smoke.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PASS=0
FAIL=0
SKIP=0

log() { echo ">>> $*"; }
pass() { PASS=$((PASS + 1)); echo "[PASS] $*"; }
fail() { FAIL=$((FAIL + 1)); echo "[FAIL] $*" >&2; }
skip() { SKIP=$((SKIP + 1)); echo "[SKIP] $*"; }

run_step() {
  local name="$1"
  shift
  log "$name"
  if "$@"; then
    pass "$name"
  else
    fail "$name"
    return 1
  fi
}

# ── 1. Go 单测 ─────────────────────────────────────────────
run_go_tests() {
  local dir ok=0
  for dir in services/hello services/_template/go; do
    if [[ ! -d "$dir" ]]; then
      fail "目录缺失: $dir"
      ok=1
      continue
    fi
    log "go test ./... in $dir"
    if (cd "$dir" && go test ./...); then
      pass "go test $dir"
    else
      fail "go test $dir"
      ok=1
    fi
  done
  return "$ok"
}

# ── 2. 契约 lint ───────────────────────────────────────────
run_contract_lint() {
  if [[ ! -x scripts/contract-lint.sh ]]; then
    chmod +x scripts/contract-lint.sh
  fi
  ./scripts/contract-lint.sh
}

# ── 3. infra shell 语法检查 ──────────────────────────────────
run_bash_syntax() {
  local script ok=0
  local scripts=(
    infra/observability/scripts/deploy-dev.sh
    infra/gateway/scripts/health-check.sh
    infra/messaging/scripts/produce-consume-test.sh
    infra/data/scripts/connectivity-test.sh
    infra/ci/docker-build.sh
  )
  for script in "${scripts[@]}"; do
    if [[ ! -f "$script" ]]; then
      fail "脚本缺失: $script"
      ok=1
      continue
    fi
    log "bash -n $script"
    if bash -n "$script"; then
      pass "bash -n $script"
    else
      fail "bash -n $script"
      ok=1
    fi
  done
  return "$ok"
}

# ── 4. 关键目录存在性 ───────────────────────────────────────
run_dir_checks() {
  local dir ok=0
  local dirs=(
    ios
    ios/BabyCamera.xcodeproj
    ios/Packages/BabyCameraNetwork
    ios/Packages/Database
    ios/Packages/DesignSystem
    services
    services/hello
    services/_template
    services/_template/go
    contracts
    contracts/openapi
    contracts/protobuf
    infra
    infra/k8s
    infra/gateway
    infra/data
    infra/messaging
    infra/storage
    infra/vault
    infra/observability
    infra/argocd
    tests
    compliance
    design-assets
    scripts
  )
  for dir in "${dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      pass "dir exists: $dir"
    else
      fail "dir missing: $dir"
      ok=1
    fi
  done
  return "$ok"
}

# ── 5. P0-4 产出物（可选增强，不阻断主流程） ─────────────────
check_p0_4_artifacts() {
  local ok=0
  if [[ -d services/config-svc ]]; then
    pass "T0.19: services/config-svc"
  else
    skip "T0.19: services/config-svc 尚未创建"
    ok=1
  fi
  if [[ -d tests/mocks ]] || [[ -d tests/e2e ]] || [[ -d tests/integration ]]; then
    pass "T0.20: tests 子目录"
  else
    skip "T0.20: tests/{integration,e2e,mocks} 尚未创建"
    ok=1
  fi
  return 0
}

main() {
  log "P0 smoke 开始 — ROOT=$ROOT"
  echo

  set +e
  run_go_tests || true
  echo
  run_contract_lint && pass "contract-lint" || fail "contract-lint"
  echo
  run_bash_syntax || true
  echo
  run_dir_checks || true
  echo
  check_p0_4_artifacts || true
  set -e

  echo
  echo "========================================"
  echo "P0 smoke 汇总: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
  echo "========================================"

  if [[ "$FAIL" -gt 0 ]]; then
    exit 1
  fi
  exit 0
}

main "$@"
