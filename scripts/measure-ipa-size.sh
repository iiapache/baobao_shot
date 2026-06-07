#!/usr/bin/env bash
# T7.7: 估算 IPA / .app / .xcarchive 安装包体积，对照 design-ios §14 预算 ≤ 80 MB。
# 用法:
#   ./scripts/measure-ipa-size.sh path/to/BabyCamera.ipa
#   ./scripts/measure-ipa-size.sh path/to/BabyCamera.app
#   ./scripts/measure-ipa-size.sh path/to/BabyCamera.xcarchive
#   ./scripts/measure-ipa-size.sh   # 尝试在 ios/ 下定位最近构建产物
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUDGET_MB=80
BUDGET_BYTES=$((BUDGET_MB * 1024 * 1024))
# App Store 下载体积通常为未压缩体量的 ~60–70%；此处用 0.65 作保守估算
COMPRESSION_FACTOR="${COMPRESSION_FACTOR:-0.65}"

bytes_to_mb() {
  awk -v b="$1" 'BEGIN { printf "%.2f", b / 1048576 }'
}

dir_size_bytes() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    echo 0
    return
  fi
  du -sk "$path" | awk '{ print $1 * 1024 }'
}

estimate_install_bytes() {
  local uncompressed="$1"
  awk -v u="$uncompressed" -v f="$COMPRESSION_FACTOR" 'BEGIN { printf "%.0f", u * f }'
}

WORK_DIR=""

cleanup_work_dir() {
  if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
    rm -rf "$WORK_DIR"
  fi
}

resolve_app_bundle() {
  local input="${1:-}"

  if [[ -z "$input" ]]; then
    local candidates=(
      "$ROOT/ios/build/Build/Products/Release-iphoneos/BabyCamera.app"
      "$ROOT/ios/build/Build/Products/Debug-iphoneos/BabyCamera.app"
    )
    for c in "${candidates[@]}"; do
      if [[ -d "$c" ]]; then
        echo "$c"
        return 0
      fi
    done
    echo "未指定路径，且未找到默认 .app 构建产物。请先 Archive 或传入 .ipa / .xcarchive / .app 路径。" >&2
    return 1
  fi

  if [[ ! -e "$input" ]]; then
    echo "路径不存在: $input" >&2
    return 1
  fi

  case "$input" in
    *.ipa)
      WORK_DIR="$(mktemp -d)"
      unzip -q "$input" -d "$WORK_DIR"
      local app
      app="$(find "$WORK_DIR/Payload" -maxdepth 1 -name '*.app' -print -quit)"
      if [[ -z "$app" ]]; then
        echo "IPA 内未找到 Payload/*.app: $input" >&2
        return 1
      fi
      echo "$app"
      ;;
    *.xcarchive)
      local app
      app="$(find "$input/Products/Applications" -maxdepth 1 -name '*.app' -print -quit)"
      if [[ -z "$app" ]]; then
        echo "xcarchive 内未找到 Products/Applications/*.app: $input" >&2
        return 1
      fi
      echo "$app"
      ;;
    *.app)
      echo "$input"
      ;;
    *)
      echo "不支持的文件类型: $input（支持 .ipa / .app / .xcarchive）" >&2
      return 1
      ;;
  esac
}

print_section() {
  local label="$1"
  local path="$2"
  local bytes
  bytes="$(dir_size_bytes "$path")"
  printf "  %-28s %8s MB  (%s)\n" "$label" "$(bytes_to_mb "$bytes")" "$path"
}

main() {
  trap cleanup_work_dir EXIT
  local input="${1:-}"
  local app_bundle
  app_bundle="$(resolve_app_bundle "$input")"

  local total_uncompressed
  total_uncompressed="$(dir_size_bytes "$app_bundle")"

  echo "=== BabyCamera 安装包体积估算 (T7.7) ==="
  echo "App Bundle: $app_bundle"
  echo "预算: ≤ ${BUDGET_MB} MB（主包，不含 ODR 按需资源）"
  echo "压缩系数: ${COMPRESSION_FACTOR}（可用 COMPRESSION_FACTOR 环境变量覆盖）"
  echo ""

  echo "--- 未压缩明细 ---"
  print_section "App 根目录" "$app_bundle"

  if [[ -d "$app_bundle/Frameworks" ]]; then
    print_section "Frameworks/" "$app_bundle/Frameworks"
  else
    echo "  Frameworks/                         0.00 MB  (无)"
  fi

  if [[ -d "$app_bundle/PlugIns" ]]; then
    print_section "PlugIns/ (含 Widget)" "$app_bundle/PlugIns"
  else
    echo "  PlugIns/                            0.00 MB  (无)"
  fi

  local install_bytes install_mb uncompressed_mb
  install_bytes="$(estimate_install_bytes "$total_uncompressed")"
  install_mb="$(bytes_to_mb "$install_bytes")"
  uncompressed_mb="$(bytes_to_mb "$total_uncompressed")"

  echo ""
  echo "--- 汇总 ---"
  echo "UNCOMPRESSED_MB=${uncompressed_mb}"
  echo "INSTALL_SIZE_MB=${install_mb}"
  echo "INSTALL_SIZE_BYTES=${install_bytes}"
  echo "BUDGET_MB=${BUDGET_MB}"
  echo "BUDGET_BYTES=${BUDGET_BYTES}"

  if [[ "$install_bytes" -le "$BUDGET_BYTES" ]]; then
    echo "RESULT=PASS"
    echo ""
    echo "✅ 估算安装体积 ${install_mb} MB ≤ ${BUDGET_MB} MB"
  else
    echo "RESULT=FAIL"
    echo ""
    echo "❌ 估算安装体积 ${install_mb} MB 超出预算 ${BUDGET_MB} MB" >&2
    echo "提示: 将贴纸 / 字体迁移至 ODR（见 ios/ODR/README.md）" >&2
    exit 1
  fi

  echo ""
  echo "ODR 说明: Asset Catalog tag \`editor-fonts\` / \`editor-stickers\` 资源不计入上述主包估算。"
  echo "完整用户下载体积请在 App Store Connect → App Size 查看。"
}

main "$@"
