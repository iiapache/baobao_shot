#!/usr/bin/env bash
# ENV-01：检测完整 Xcode 16+ 工具链（非仅 Command Line Tools）
# 用法:
#   ./ios/scripts/verify-xcode-env.sh           # 人类可读报告
#   ./ios/scripts/verify-xcode-env.sh --json    # JSON 输出（CI / 自动化）
set -euo pipefail

IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REQUIRED_XCODE_MAJOR=16
REQUIRED_IOS_SDK_MAJOR=18
JSON_MODE=0
FAILURES=()
WARNINGS=()
REPORT=()
GUIDE_PRINTED=0

if [[ "${1:-}" == "--json" ]]; then
  JSON_MODE=1
fi

log() {
  if [[ "$JSON_MODE" -eq 0 ]]; then
    echo ">>> $*"
  fi
}

pass() {
  REPORT+=("PASS: $*")
  if [[ "$JSON_MODE" -eq 0 ]]; then
    echo "[PASS] $*"
  fi
}

warn() {
  WARNINGS+=("$*")
  REPORT+=("WARN: $*")
  if [[ "$JSON_MODE" -eq 0 ]]; then
    echo "[WARN] $*" >&2
  fi
}

fail() {
  FAILURES+=("$*")
  REPORT+=("FAIL: $*")
  if [[ "$JSON_MODE" -eq 0 ]]; then
    echo "[FAIL] $*" >&2
  fi
}

print_install_guide() {
  if [[ "$JSON_MODE" -eq 1 || "$GUIDE_PRINTED" -eq 1 ]]; then
    return
  fi
  GUIDE_PRINTED=1
  cat >&2 <<'EOF'

── 安装指引（ENV-01）──────────────────────────────────────
本仓库 iOS 构建需要完整 Xcode 16+（含 iOS 18 SDK），不能仅安装 Command Line Tools。

1. 安装 Xcode
   - Mac App Store 搜索「Xcode」，或
   - https://developer.apple.com/xcode/ 下载 Xcode 16.x

2. 切换开发者目录（安装后执行一次）
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

3. 接受许可并安装组件
   sudo xcodebuild -license accept
   open -a Xcode   # 首次启动，等待「Installing additional components」完成

4. 验证
   ./ios/scripts/verify-xcode-env.sh
   ./ios/scripts/build-babycamera.sh

若存在多个 Xcode 版本，将路径中的 Xcode.app 替换为实际名称（如 Xcode-16.2.app）。
──────────────────────────────────────────────────────────
EOF
}

version_major() {
  local version="$1"
  echo "${version%%.*}"
}

# ── 1. 平台 ──────────────────────────────────────────────
if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "当前系统为 $(uname -s)，iOS 构建仅支持 macOS"
  if [[ "$JSON_MODE" -eq 1 ]]; then
    printf '{"ok":false,"platform":"%s","failures":["non-macos"]}\n' "$(uname -s)"
  else
    echo ">>> 在 macOS runner 或本地 Mac 上运行本脚本。"
  fi
  exit 1
fi
pass "运行平台: macOS $(sw_vers -productVersion)"

# ── 2. Xcode.app 是否存在 ────────────────────────────────
XCODE_APP=""
if [[ -d "/Applications/Xcode.app" ]]; then
  XCODE_APP="/Applications/Xcode.app"
elif compgen -G "/Applications/Xcode*.app" >/dev/null; then
  # 取版本号最高的 Xcode（按路径名排序后取最后一个）
  XCODE_APP="$(ls -d /Applications/Xcode*.app 2>/dev/null | sort -V | tail -1)"
fi

if [[ -z "$XCODE_APP" ]]; then
  fail "未找到 /Applications/Xcode.app（仅检测到 Command Line Tools 或尚未安装 Xcode）"
  print_install_guide
else
  pass "Xcode 应用: ${XCODE_APP}"
fi

# ── 3. xcode-select 指向 ─────────────────────────────────
DEV_DIR=""
if DEV_DIR="$(xcode-select -p 2>/dev/null)"; then
  if [[ "$DEV_DIR" == *"CommandLineTools"* ]]; then
    fail "xcode-select 指向 Command Line Tools: ${DEV_DIR}"
    fail "需要执行: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    print_install_guide
  elif [[ "$DEV_DIR" == *"Xcode.app"* ]]; then
    pass "开发者目录: ${DEV_DIR}"
  else
    warn "开发者目录非常规路径: ${DEV_DIR}"
  fi
else
  fail "xcode-select -p 失败，开发者工具未配置"
  print_install_guide
fi

# ── 4. xcodebuild 版本 ───────────────────────────────────
XCODE_VERSION=""
XCODE_BUILD=""
if XCODE_OUT="$(xcodebuild -version 2>&1)"; then
  XCODE_VERSION="$(echo "$XCODE_OUT" | awk '/^Xcode /{print $2; exit}')"
  XCODE_BUILD="$(echo "$XCODE_OUT" | awk '/^Build version /{print $3; exit}')"
  if [[ -n "$XCODE_VERSION" ]]; then
    XCODE_MAJOR="$(version_major "$XCODE_VERSION")"
    if [[ "$XCODE_MAJOR" -ge "$REQUIRED_XCODE_MAJOR" ]]; then
      pass "Xcode 版本: ${XCODE_VERSION} (build ${XCODE_BUILD:-unknown})"
    else
      fail "Xcode 版本 ${XCODE_VERSION} < 要求的 ${REQUIRED_XCODE_MAJOR}+"
    fi
  else
    fail "无法解析 xcodebuild -version 输出"
  fi
else
  fail "xcodebuild 不可用: ${XCODE_OUT}"
  print_install_guide
fi

# ── 5. Command Line Tools ────────────────────────────────
CLT_VERSION=""
if CLT_PKG="$(pkgutil --pkg-info=com.apple.pkg.CLTools_Executables 2>/dev/null)"; then
  CLT_VERSION="$(echo "$CLT_PKG" | awk -F': ' '/version:/{print $2; exit}')"
  pass "Command Line Tools: ${CLT_VERSION}"
else
  warn "未检测到独立 CLT 包信息（完整 Xcode 通常已包含，可忽略）"
fi

# ── 6. iOS SDK ───────────────────────────────────────────
IOS_SDK_VERSION=""
IOS_SDK_PATH=""
if SDK_OUT="$(xcodebuild -showsdks 2>/dev/null)"; then
  IOS_SDK_LINE="$(echo "$SDK_OUT" | grep -E '^\s*iOS [0-9]' | tail -1 || true)"
  if [[ -n "$IOS_SDK_LINE" ]]; then
    IOS_SDK_VERSION="$(echo "$IOS_SDK_LINE" | sed -E 's/^[[:space:]]*iOS ([0-9.]+).*/\1/')"
    IOS_SDK_PATH="$(echo "$IOS_SDK_LINE" | sed -E 's/.*-sdk (.*)$/\1/')"
    IOS_SDK_MAJOR="$(version_major "$IOS_SDK_VERSION")"
    if [[ "$IOS_SDK_MAJOR" -ge "$REQUIRED_IOS_SDK_MAJOR" ]]; then
      pass "iOS SDK: ${IOS_SDK_VERSION} (${IOS_SDK_PATH})"
    else
      warn "iOS SDK ${IOS_SDK_VERSION} < 推荐 ${REQUIRED_IOS_SDK_MAJOR}+（可构建但建议升级 Xcode）"
    fi
  else
    fail "xcodebuild -showsdks 未列出 iOS SDK"
  fi
else
  fail "无法执行 xcodebuild -showsdks"
fi

# ── 7. Swift ─────────────────────────────────────────────
if SWIFT_OUT="$(swift --version 2>&1)"; then
  SWIFT_VER="$(echo "$SWIFT_OUT" | head -1)"
  pass "Swift: ${SWIFT_VER}"
else
  warn "swift 命令不可用"
fi

# ── 8. 工程文件 ──────────────────────────────────────────
for required in \
  "BabyCamera.xcodeproj" \
  "BabyCamera.xcworkspace" \
  "BabyCamera.xcodeproj/xcshareddata/xcschemes/BabyCamera.xcscheme"
do
  if [[ -e "${IOS_DIR}/${required}" ]]; then
    pass "工程文件存在: ${required}"
  else
    fail "缺少工程文件: ios/${required}"
  fi
done

# ── 9. 许可状态（可选）──────────────────────────────────
if xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
  pass "Xcode 首次启动组件已就绪"
else
  warn "Xcode 可能尚未完成首次启动（请 open -a Xcode 并等待组件安装）"
fi

# ── 汇总 ─────────────────────────────────────────────────
OK=1
if [[ "${#FAILURES[@]}" -gt 0 ]]; then
  OK=0
fi

if [[ "$JSON_MODE" -eq 1 ]]; then
  python3 - <<PY
import json
print(json.dumps({
    "ok": bool(${OK}),
    "platform": "macOS",
    "xcode_app": "${XCODE_APP:-}",
    "developer_dir": "${DEV_DIR:-}",
    "xcode_version": "${XCODE_VERSION:-}",
    "xcode_build": "${XCODE_BUILD:-}",
    "clt_version": "${CLT_VERSION:-}",
    "ios_sdk_version": "${IOS_SDK_VERSION:-}",
    "ios_sdk_path": "${IOS_SDK_PATH:-}",
    "required_xcode_major": ${REQUIRED_XCODE_MAJOR},
    "failures": $(python3 -c 'import json,sys; print(json.dumps(sys.argv[1:]))' "${FAILURES[@]:-}"),
    "warnings": $(python3 -c 'import json,sys; print(json.dumps(sys.argv[1:]))' "${WARNINGS[@]:-}"),
}, ensure_ascii=False))
PY
else
  echo ""
  if [[ "$OK" -eq 1 ]]; then
    log "Xcode 环境检测通过，可执行: ./ios/scripts/build-babycamera.sh"
  else
    log "Xcode 环境检测未通过（${#FAILURES[@]} 项失败）"
    print_install_guide
  fi
fi

exit "$((1 - OK))"
