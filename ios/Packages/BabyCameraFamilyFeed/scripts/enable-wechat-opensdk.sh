#!/usr/bin/env bash
# 取消 Package.swift 中 WechatOpenSDK SPM 注释，供 Staging/Release 真机分享联调。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE_SWIFT="$ROOT/Package.swift"

if [[ "$(uname -s)" == "Darwin" ]]; then
  sed -i '' 's|^[[:space:]]*// \(.*package(url: "https://github.com/yanyin1986/WechatOpenSDK.git".*\)|        \1|' "$PACKAGE_SWIFT"
  sed -i '' 's|^[[:space:]]*// \(.*product(name: "WechatOpenSDK".*\)|                \1|' "$PACKAGE_SWIFT"
else
  sed -i 's|^[[:space:]]*// \(.*package(url: "https://github.com/yanyin1986/WechatOpenSDK.git".*\)|        \1|' "$PACKAGE_SWIFT"
  sed -i 's|^[[:space:]]*// \(.*product(name: "WechatOpenSDK".*\)|                \1|' "$PACKAGE_SWIFT"
fi

echo "WechatOpenSDK SPM enabled in $PACKAGE_SWIFT — run 'swift package resolve' or Xcode Resolve Packages."
