#!/usr/bin/env bash
# ENV-02: 检测 Apple 签名与 fastlane match 前置条件
# 用法: cd ios && ./scripts/verify-signing.sh
# 退出码: 0=全部通过, 1=存在阻塞项

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${IOS_DIR}/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass=0
warn=0
fail=0

log_pass() { echo -e "${GREEN}[PASS]${NC} $*"; pass=$((pass + 1)); }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; warn=$((warn + 1)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $*"; fail=$((fail + 1)); }

section() {
  echo ""
  echo "── $* ──"
}

is_placeholder() {
  local value="${1:-}"
  [[ -z "${value}" || "${value}" == "YOUR_TEAM_ID" || "${value}" == *"YOUR_ORG"* || "${value}" == *"example.com"* ]]
}

section "1. 运行环境"
if [[ "$(uname -s)" == "Darwin" ]]; then
  log_pass "macOS 环境"
else
  log_fail "非 macOS，无法执行签名与 Archive（仅可检查配置文件）"
fi

section "2. Xcode"
if command -v xcodebuild >/dev/null 2>&1; then
  xcode_ver="$(xcodebuild -version 2>/dev/null | head -1 || true)"
  if [[ -n "${xcode_ver}" ]]; then
    log_pass "Xcode 已安装: ${xcode_ver}"
  else
    log_fail "xcodebuild 不可用"
  fi
else
  log_fail "未找到 xcodebuild（需完整 Xcode 16+，非仅 Command Line Tools）"
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
  if xcode-select -p >/dev/null 2>&1; then
    log_pass "xcode-select: $(xcode-select -p)"
  else
    log_fail "xcode-select 未配置，运行: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  fi
fi

section "3. 工程文件"
for f in \
  "${IOS_DIR}/BabyCamera.xcodeproj" \
  "${IOS_DIR}/BabyCamera.xcworkspace" \
  "${IOS_DIR}/fastlane/Fastfile" \
  "${IOS_DIR}/fastlane/Matchfile" \
  "${IOS_DIR}/fastlane/Appfile" \
  "${IOS_DIR}/Gemfile"
do
  if [[ -e "${f}" ]]; then
    log_pass "存在 $(basename "${f}")"
  else
    log_fail "缺失 ${f}"
  fi
done

section "4. Bundler / fastlane"
if command -v bundle >/dev/null 2>&1; then
  log_pass "Bundler 已安装"
else
  log_warn "未安装 Bundler，运行: gem install bundler"
fi

if [[ -f "${IOS_DIR}/Gemfile.lock" ]]; then
  log_pass "Gemfile.lock 存在（依赖已锁定）"
else
  log_warn "Gemfile.lock 缺失，在 ios/ 运行: bundle install"
fi

section "5. 环境变量"
check_env() {
  local name="$1"
  local required="${2:-true}"
  local value="${!name:-}"

  if [[ -n "${value}" ]] && ! is_placeholder "${value}"; then
    log_pass "${name} 已设置"
  elif [[ "${required}" == "true" ]]; then
    log_fail "${name} 未设置或为占位值"
  else
    log_warn "${name} 未设置（可选）"
  fi
}

check_env "FASTLANE_TEAM_ID" true
check_env "MATCH_GIT_URL" true
check_env "MATCH_PASSWORD" true
check_env "FASTLANE_USER" false
check_env "APP_STORE_CONNECT_API_KEY_PATH" false
check_env "APP_STORE_CONNECT_API_KEY_ID" false
check_env "APP_STORE_CONNECT_API_ISSUER_ID" false

section "6. Keychain 签名证书"
if [[ "$(uname -s)" == "Darwin" ]]; then
  identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"
  if echo "${identities}" | grep -q "Apple Distribution"; then
    log_pass "Keychain 含 Apple Distribution 证书"
  elif echo "${identities}" | grep -q "Apple Development"; then
    log_warn "仅有 Apple Development 证书，TestFlight 需 Apple Distribution（match appstore）"
  else
    log_fail "Keychain 无有效 codesigning 身份，需先执行 match"
  fi

  echo "${identities}" | grep -E "^\s+[0-9]+\)" | head -5 || true
else
  log_warn "跳过 Keychain 检查（非 macOS）"
fi

section "7. Provisioning Profile"
PROFILE_DIR="${HOME}/Library/MobileDevice/Provisioning Profiles"
if [[ -d "${PROFILE_DIR}" ]]; then
  count="$(find "${PROFILE_DIR}" -name "*.mobileprovision" 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "${count}" -gt 0 ]]; then
    log_pass "已安装 ${count} 个 Provisioning Profile"
  else
    log_fail "Provisioning Profiles 目录为空，需 match appstore"
  fi
else
  log_fail "Provisioning Profiles 目录不存在"
fi

section "8. match 只读探测（可选）"
if [[ "$(uname -s)" == "Darwin" ]] \
  && [[ -n "${MATCH_PASSWORD:-}" ]] \
  && [[ -n "${MATCH_GIT_URL:-}" ]] \
  && ! is_placeholder "${MATCH_GIT_URL}" \
  && [[ -f "${IOS_DIR}/Gemfile.lock" ]]; then
  if (cd "${IOS_DIR}" && bundle exec fastlane match appstore --readonly 2>&1); then
    log_pass "match appstore --readonly 成功"
  else
    log_fail "match 只读拉取失败（检查 MATCH_GIT_URL / 仓库权限 / MATCH_PASSWORD）"
  fi
else
  log_warn "跳过 match 探测（环境变量或 bundle 未就绪）"
fi

section "9. 文档"
if [[ -f "${REPO_ROOT}/docs/qa/TESTFLIGHT_BUILD_CHECKLIST.md" ]]; then
  log_pass "TESTFLIGHT_BUILD_CHECKLIST.md 存在"
else
  log_fail "缺失 docs/qa/TESTFLIGHT_BUILD_CHECKLIST.md"
fi

section "汇总"
echo ""
echo "通过: ${pass}  警告: ${warn}  失败: ${fail}"
echo ""
echo "下一步:"
echo "  1. 按 docs/qa/TESTFLIGHT_BUILD_CHECKLIST.md 完成 Apple 账号与 match 初始化"
echo "  2. cd ios && bundle install"
echo "  3. export MATCH_PASSWORD FASTLANE_TEAM_ID MATCH_GIT_URL"
echo "  4. bundle exec fastlane beta          # 构建 + 上传 TestFlight"
echo "  5. bundle exec fastlane build_only     # 仅产出 IPA（不上传）"
echo ""

if [[ "${fail}" -gt 0 ]]; then
  exit 1
fi
exit 0
