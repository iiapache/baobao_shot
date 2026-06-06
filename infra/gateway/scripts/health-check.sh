#!/usr/bin/env bash
# 网关健康检查 — T0.6 验收脚本
#
# 用法:
#   ./infra/gateway/scripts/health-check.sh
#   ./infra/gateway/scripts/health-check.sh --host dev-api-cn.example.com --resolve 127.0.0.1
#   ./infra/gateway/scripts/health-check.sh --check-tls --check-http2
#   ./infra/gateway/scripts/health-check.sh --check-auth   # T1.12 JWT / refresh
#
# 环境变量:
#   GATEWAY_HOST     默认 dev-api-cn.example.com
#   GATEWAY_RESOLVE  可选，格式 host:port:ip（传给 curl --resolve）
#   WS_HOST          默认 dev-ws-cn.example.com
#   INSECURE         1 = 跳过 TLS 校验（本地 kind 无有效证书时）

set -euo pipefail

HOST="${GATEWAY_HOST:-dev-api-cn.example.com}"
WS_HOST="${WS_HOST:-dev-ws-cn.example.com}"
RESOLVE="${GATEWAY_RESOLVE:-}"
INSECURE="${INSECURE:-0}"
CHECK_TLS=false
CHECK_HTTP2=false
CHECK_AUTH=false
PATH_HEALTH="/health"
PATH_V1="/v1/echo"
PATH_FAMILIES="/v1/families"
PATH_AUTH_REFRESH="/v1/auth/refresh"

usage() {
  sed -n '2,12p' "$0"
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage 0 ;;
    --host) HOST="$2"; shift 2 ;;
    --ws-host) WS_HOST="$2"; shift 2 ;;
    --resolve) RESOLVE="$2"; shift 2 ;;
    --check-tls) CHECK_TLS=true; shift ;;
    --check-http2) CHECK_HTTP2=true; shift ;;
    --check-auth) CHECK_AUTH=true; shift ;;
    --insecure) INSECURE=1; shift ;;
    *) echo "未知参数: $1" >&2; usage 1 ;;
  esac
done

CURL_OPTS=(-sS -o /dev/null -w "%{http_code}")
if [[ "$INSECURE" == "1" ]]; then
  CURL_OPTS+=(-k)
fi
if [[ -n "$RESOLVE" ]]; then
  CURL_OPTS+=(--resolve "${HOST}:443:${RESOLVE}")
fi

echo "==> 网关健康检查 host=${HOST}"

# --- HTTP(S) 200 健康检查 ---
HEALTH_URL="https://${HOST}${PATH_HEALTH}"
CODE=$(curl "${CURL_OPTS[@]}" "$HEALTH_URL")
if [[ "$CODE" != "200" ]]; then
  echo "FAIL: GET ${HEALTH_URL} → HTTP ${CODE} (期望 200)" >&2
  exit 1
fi
echo "OK: GET ${PATH_HEALTH} → HTTP ${CODE}"

V1_URL="https://${HOST}${PATH_V1}"
CODE_V1=$(curl "${CURL_OPTS[@]}" "$V1_URL" || true)
if [[ "$CODE_V1" == "200" ]]; then
  echo "OK: GET ${PATH_V1} → HTTP ${CODE_V1}"
else
  echo "WARN: GET ${PATH_V1} → HTTP ${CODE_V1} (hello 未部署时可忽略)"
fi

# --- HTTP/2 检查 ---
if [[ "$CHECK_HTTP2" == true ]]; then
  H2_OUT=$(curl -sS -I --http2 --tlsv1.3 --tls-max 1.3 \
    "${INSECURE:+ -k}" \
    ${RESOLVE:+--resolve "${HOST}:443:${RESOLVE}"} \
    "https://${HOST}${PATH_HEALTH}" 2>&1 | head -1)
  if echo "$H2_OUT" | grep -qE 'HTTP/2 200|HTTP/2.0 200'; then
    echo "OK: HTTP/2 启用 → ${H2_OUT}"
  else
    echo "FAIL: 未检测到 HTTP/2 200 → ${H2_OUT}" >&2
    exit 1
  fi
fi

# --- TLS 1.3 强制检查 ---
if [[ "$CHECK_TLS" == true ]]; then
  if ! command -v openssl >/dev/null 2>&1; then
    echo "WARN: openssl 未安装，跳过 TLS 检查" >&2
  else
    ENDPOINT="${HOST}:443"
    if [[ -n "$RESOLVE" ]]; then
      ENDPOINT="${RESOLVE}:443"
    fi
    PROTO=$(echo | openssl s_client -connect "$ENDPOINT" -tls1_3 -servername "$HOST" 2>/dev/null \
      | grep -i "Protocol" | head -1 || true)
    if echo "$PROTO" | grep -qi "TLSv1.3"; then
      echo "OK: TLS 1.3 握手成功 → ${PROTO}"
    else
      echo "FAIL: TLS 1.3 握手失败 → ${PROTO:-empty}" >&2
      exit 1
    fi
    # TLS 1.2 应被拒绝
    if echo | openssl s_client -connect "$ENDPOINT" -tls1_2 -servername "$HOST" 2>&1 \
      | grep -qiE "alert|wrong version|no protocols"; then
      echo "OK: TLS 1.2 已拒绝（符合强制 TLS 1.3）"
    else
      echo "WARN: TLS 1.2 可能仍可用，请核对 apisix.set_config.ssl_protocols"
    fi
  fi
fi

# --- WebSocket 域名可达性（HTTP 层，非完整 WS 握手）---
WS_URL="https://${WS_HOST}/ws/v1/ping"
WS_OPTS=(-sS -o /dev/null -w "%{http_code}")
[[ "$INSECURE" == "1" ]] && WS_OPTS+=(-k)
if [[ -n "$RESOLVE" ]]; then
  WS_OPTS+=(--resolve "${WS_HOST}:443:${RESOLVE}")
fi
WS_CODE=$(curl "${WS_OPTS[@]}" "$WS_URL" 2>/dev/null || echo "000")
if [[ "$WS_CODE" =~ ^(200|404|426)$ ]]; then
  echo "OK: WS host ${WS_HOST} 可达 → HTTP ${WS_CODE}"
else
  echo "WARN: WS host ${WS_HOST} → HTTP ${WS_CODE} (路由未应用时可忽略)"
fi

# --- T1.12 JWT / refresh 路由检查 ---
if [[ "$CHECK_AUTH" == true ]]; then
  AUTH_OPTS=(-sS)
  [[ "$INSECURE" == "1" ]] && AUTH_OPTS+=(-k)
  if [[ -n "$RESOLVE" ]]; then
    AUTH_OPTS+=(--resolve "${HOST}:443:${RESOLVE}")
  fi

  # 无 Token 访问受保护路由 → 401 + AUTH_TOKEN_EXPIRED
  PROTECTED_BODY=$(curl "${AUTH_OPTS[@]}" -w "\n%{http_code}" \
    "https://${HOST}${PATH_FAMILIES}" 2>/dev/null || echo -e "\n000")
  PROTECTED_CODE=$(echo "$PROTECTED_BODY" | tail -1)
  PROTECTED_JSON=$(echo "$PROTECTED_BODY" | sed '$d')
  if [[ "$PROTECTED_CODE" == "401" ]] && echo "$PROTECTED_JSON" | grep -q "AUTH_TOKEN_EXPIRED"; then
    echo "OK: GET ${PATH_FAMILIES} 无 Token → HTTP 401 AUTH_TOKEN_EXPIRED"
  else
    echo "FAIL: GET ${PATH_FAMILIES} 无 Token → HTTP ${PROTECTED_CODE} (期望 401 + AUTH_TOKEN_EXPIRED)" >&2
    echo "      body: ${PROTECTED_JSON}" >&2
    exit 1
  fi

  # refresh 路由无需 Access Token（空 body → 400，非 401）
  REFRESH_CODE=$(curl "${AUTH_OPTS[@]}" -o /dev/null -w "%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-Device-Id: health-check-device" \
    -d '{}' \
    "https://${HOST}${PATH_AUTH_REFRESH}" 2>/dev/null || echo "000")
  if [[ "$REFRESH_CODE" =~ ^(400|422)$ ]]; then
    echo "OK: POST ${PATH_AUTH_REFRESH} 无 Access Token → HTTP ${REFRESH_CODE}（非 401）"
  elif [[ "$REFRESH_CODE" == "401" ]]; then
    echo "FAIL: POST ${PATH_AUTH_REFRESH} 不应要求 Access Token，却返回 401" >&2
    exit 1
  else
    echo "WARN: POST ${PATH_AUTH_REFRESH} → HTTP ${REFRESH_CODE}（auth-family-svc 未部署时可忽略）"
  fi
fi

echo "==> 健康检查完成"
