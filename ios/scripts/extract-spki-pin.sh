#!/usr/bin/env bash
# 从线上 TLS 证书提取 SPKI SHA-256 pin（Base64）。
# 注意：OpenSSL 输出为 SubjectPublicKeyInfo DER 直哈希；iOS 端对 RSA/EC 使用 TrustKit 风格 SPKI 前缀 + raw key。
# 运维应以真机抓包或 Apple SecKey 导出为准；本脚本用于快速初值，上线前须与 App 校验结果对齐。
set -euo pipefail

HOST="${1:?用法: $0 <hostname>}"
PORT="${2:-443}"

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

echo | openssl s_client -connect "${HOST}:${PORT}" -servername "$HOST" 2>/dev/null \
  | openssl x509 -outform PEM > "$TMP"

if [[ ! -s "$TMP" ]]; then
  echo "无法获取 ${HOST} 证书" >&2
  exit 1
fi

HASH="$(openssl x509 -in "$TMP" -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary | base64)"

echo "# ${HOST} (OpenSSL SPKI DER — 与 iOS 算法可能不同，请真机验证)"
echo "${HASH}"
