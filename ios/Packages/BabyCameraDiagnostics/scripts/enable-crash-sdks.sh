#!/usr/bin/env bash
# 取消 Package.swift 中 Sentry SPM 注释，供 Staging/Release 本地或 CI 构建使用。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE_SWIFT="$ROOT/Package.swift"

if [[ "$(uname -s)" == "Darwin" ]]; then
  sed -i '' 's|^[[:space:]]*// \(.*package(url: "https://github.com/getsentry/sentry-cocoa".*\)|        \1|' "$PACKAGE_SWIFT"
  sed -i '' 's|^[[:space:]]*// \(.*product(name: "Sentry".*\)|                \1|' "$PACKAGE_SWIFT"
else
  sed -i 's|^[[:space:]]*// \(.*package(url: "https://github.com/getsentry/sentry-cocoa".*\)|        \1|' "$PACKAGE_SWIFT"
  sed -i 's|^[[:space:]]*// \(.*product(name: "Sentry".*\)|                \1|' "$PACKAGE_SWIFT"
fi

echo "Sentry SPM enabled in $PACKAGE_SWIFT — run 'swift package resolve' or Xcode Resolve Packages."
