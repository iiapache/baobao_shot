#!/usr/bin/env bash
# ENV-01：一键构建 BabyCamera（需先通过 verify-xcode-env.sh）
# 用法:
#   ./ios/scripts/build-babycamera.sh
#   ./ios/scripts/build-babycamera.sh --simulator "iPhone 16"
#   ./ios/scripts/build-babycamera.sh --destination 'generic/platform=iOS'
#   ./ios/scripts/build-babycamera.sh --skip-verify   # 跳过环境检测（CI 已验证时）
set -euo pipefail

IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="${SCHEME:-BabyCamera}"
WORKSPACE="${IOS_DIR}/BabyCamera.xcworkspace"
DESTINATION="${DESTINATION:-generic/platform=iOS}"
SKIP_VERIFY=0
DERIVED_DATA="${DERIVED_DATA:-${IOS_DIR}/.build/DerivedData}"

usage() {
  cat <<EOF
用法: $(basename "$0") [选项]

选项:
  --simulator NAME     使用 iOS 模拟器 destination（默认: generic/platform=iOS）
  --destination EXPR   自定义 xcodebuild -destination 表达式
  --scheme NAME        构建 Scheme（默认: BabyCamera）
  --skip-verify        跳过 verify-xcode-env.sh
  -h, --help           显示帮助

环境变量:
  SCHEME, DESTINATION, DERIVED_DATA

示例:
  $(basename "$0")
  $(basename "$0") --simulator "iPhone 16"
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --simulator)
      DESTINATION="platform=iOS Simulator,name=${2:?缺少模拟器名称}"
      shift 2
      ;;
    --destination)
      DESTINATION="${2:?缺少 destination 表达式}"
      shift 2
      ;;
    --scheme)
      SCHEME="${2:?缺少 scheme 名称}"
      shift 2
      ;;
    --skip-verify)
      SKIP_VERIFY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知参数: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

log() { echo ">>> $*"; }

if [[ "$SKIP_VERIFY" -eq 0 ]]; then
  log "检测 Xcode 环境…"
  if ! "${IOS_DIR}/scripts/verify-xcode-env.sh"; then
    echo "[FAIL] 环境检测未通过，请先完成 Xcode 16+ 安装配置（见 ios/README.md ENV-01）" >&2
    exit 1
  fi
fi

if [[ ! -d "$WORKSPACE" ]]; then
  echo "[FAIL] 未找到 workspace: ${WORKSPACE}" >&2
  exit 1
fi

mkdir -p "$DERIVED_DATA"

log "构建 ${SCHEME}（destination: ${DESTINATION}）"
log "DerivedData: ${DERIVED_DATA}"

cd "$IOS_DIR"

set -x
xcodebuild \
  -workspace BabyCamera.xcworkspace \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA" \
  -quiet \
  build
set +x

log "构建成功: scheme=${SCHEME}"
