#!/usr/bin/env bash
# 等待 Xcode 安装完成后自动配置并构建 BabyCamera
# 用法: ./ios/scripts/wait-and-build-xcode.sh
set -euo pipefail

IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${IOS_DIR}/.." && pwd)"
POLL_SECS=30
MAX_WAIT_HOURS=3

log() { echo "[$(date '+%H:%M:%S')] $*"; }

find_xcode_app() {
  if [[ -d "/Applications/Xcode.app" ]]; then
    echo "/Applications/Xcode.app"
    return 0
  fi
  local app
  app="$(ls -d /Applications/Xcode*.app 2>/dev/null | sort -V | tail -1 || true)"
  if [[ -n "$app" && -d "$app" ]]; then
    echo "$app"
    return 0
  fi
  return 1
}

log "等待 Xcode 出现在 /Applications（App Store 安装中…）"
log "若尚未开始安装，请在已打开的 App Store 中点击「获取/安装」"
log "最长等待 ${MAX_WAIT_HOURS} 小时，每 ${POLL_SECS}s 检测一次"

deadline=$(( $(date +%s) + MAX_WAIT_HOURS * 3600 ))
XCODE_APP=""

while [[ $(date +%s) -lt $deadline ]]; do
  if XCODE_APP="$(find_xcode_app)"; then
    log "检测到: ${XCODE_APP}"
    break
  fi
  sleep "$POLL_SECS"
done

if [[ -z "${XCODE_APP:-}" ]]; then
  log "超时：仍未检测到 Xcode.app，请确认 App Store 安装完成后手动运行:"
  log "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  log "  sudo xcodebuild -license accept"
  log "  open -a Xcode   # 等待组件安装"
  log "  ${REPO_ROOT}/ios/scripts/build-babycamera.sh --simulator \"iPhone 16\""
  exit 1
fi

DEV_DIR="${XCODE_APP}/Contents/Developer"
CURRENT="$(xcode-select -p 2>/dev/null || true)"

if [[ "$CURRENT" != "$DEV_DIR" ]]; then
  log "切换 xcode-select → ${DEV_DIR}"
  log "需要输入 macOS 登录密码（sudo）"
  sudo xcode-select -s "$DEV_DIR"
fi

log "接受 Xcode 许可"
sudo xcodebuild -license accept 2>/dev/null || true

log "触发 Xcode 首次启动组件安装（若已装过会很快结束）"
open -a "$XCODE_APP" --args -QuitAfterLaunch 2>/dev/null || open -a "$XCODE_APP"
sleep 5

for i in {1..24}; do
  if xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
    log "Xcode 首次启动组件就绪"
    break
  fi
  log "等待 Xcode 组件… (${i}/24)"
  sleep 15
done

log "环境验证"
"${IOS_DIR}/scripts/verify-xcode-env.sh"

log "开始构建（模拟器 iPhone 16）"
"${IOS_DIR}/scripts/build-babycamera.sh" --simulator "iPhone 16"

log "全部完成"
