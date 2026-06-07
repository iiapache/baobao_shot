#!/usr/bin/env bash
# T7.8 安全审计自动化静态检查
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
IOS_ROOT="${REPO_ROOT}/ios"

PASS=0
FAIL=0
WARN=0

log() { printf '[security] %s\n' "$*" >&2; }

pass() { PASS=$((PASS + 1)); log "PASS: $*"; }
fail() { FAIL=$((FAIL + 1)); log "FAIL: $*"; }
warn() { WARN=$((WARN + 1)); log "WARN: $*"; }

grep_file() {
  local pattern="$1"
  local file="$2"
  local label="$3"
  if [[ -f "${file}" ]] && grep -qE "${pattern}" "${file}"; then
    pass "${label}"
  else
    fail "${label} (file: ${file})"
  fi
}

grep_repo() {
  local pattern="$1"
  local label="$2"
  local exclude="${3:-}"
  local hits
  if [[ -n "${exclude}" ]]; then
    hits=$(grep -rE "${pattern}" "${REPO_ROOT}" \
      --include='*.swift' --include='*.plist' --include='*.yaml' --include='*.json' \
      --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=DerivedData \
      2>/dev/null | grep -vE "${exclude}" || true)
  else
    hits=$(grep -rE "${pattern}" "${REPO_ROOT}" \
      --include='*.swift' --include='*.plist' \
      --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=DerivedData \
      2>/dev/null || true)
  fi
  if [[ -z "${hits}" ]]; then
    pass "${label}"
  else
    fail "${label}"
    echo "${hits}" | head -20 >&2
  fi
}

log "── Keychain 属性 ──"

grep_file \
  'kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly' \
  "${IOS_ROOT}/Packages/BabyCameraNetwork/Sources/BabyCameraNetwork/TokenStore.swift" \
  'KeychainTokenStore 使用 AfterFirstUnlockThisDeviceOnly'

grep_file \
  'kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly' \
  "${IOS_ROOT}/Packages/BabyCameraBackup/Sources/BabyCameraBackup/Provider/BaiduPan/BaiduPanTokenStore.swift" \
  'KeychainBaiduPanTokenStore 使用 AfterFirstUnlockThisDeviceOnly'

# 禁止使用较弱的 Keychain 可访问性
WEAK_KC=$(grep -rE 'kSecAttrAccessible(Always|AfterFirstUnlock)[^T]' "${IOS_ROOT}" \
  --include='*.swift' 2>/dev/null || true)
if [[ -z "${WEAK_KC}" ]]; then
  pass '无弱 Keychain 可访问性属性'
else
  fail '发现弱 Keychain 可访问性属性'
  echo "${WEAK_KC}" >&2
fi

log "── ATS 配置 ──"

INFO_PLIST="${IOS_ROOT}/BabyCamera/Resources/Info-Supplement.plist"
grep_file 'NSAppTransportSecurity' "${INFO_PLIST}" 'Info-Supplement.plist 含 NSAppTransportSecurity'
grep_file 'NSAllowsArbitraryLoads' "${INFO_PLIST}" 'Info-Supplement.plist 声明 NSAllowsArbitraryLoads'
grep_file '<false/>' "${INFO_PLIST}" 'NSAllowsArbitraryLoads 为 false'

# 禁止 ATS 例外放宽
if grep -q 'NSExceptionAllowsInsecureHTTPLoads' "${INFO_PLIST}" 2>/dev/null; then
  fail 'Info.plist 含 NSExceptionAllowsInsecureHTTPLoads 例外'
else
  pass '无 ATS 不安全 HTTP 例外'
fi

log "── Cert Pinning ──"

grep_file \
  'CertificatePinningConfigurationFactory' \
  "${IOS_ROOT}/Packages/BabyCameraNetwork/Sources/BabyCameraNetwork/Security/CertificatePinningConfigurationFactory.swift" \
  'CertificatePinningConfigurationFactory 存在'

grep_file \
  'CERT_PINNING_ENABLED = YES' \
  "${IOS_ROOT}/BabyCamera/Resources/Config/Release.xcconfig" \
  'Release 默认开启 Cert Pinning'

grep_file \
  'isEnabled' \
  "${IOS_ROOT}/Packages/BabyCameraNetwork/Sources/BabyCameraNetwork/Security/CertificatePinning.swift" \
  'Cert Pinning 可配置开关 isEnabled'

log "── App Attest（OPT-02）──"

grep_file \
  'AppAttestConfigurationFactory' \
  "${IOS_ROOT}/Packages/BabyCameraAccount/Sources/BabyCameraAccount/Security/AppAttestConfigurationFactory.swift" \
  'AppAttestConfigurationFactory 存在'

grep_file \
  'LiveAppAttestService' \
  "${IOS_ROOT}/Packages/BabyCameraAccount/Sources/BabyCameraAccount/Security/LiveAppAttestService.swift" \
  'LiveAppAttestService 真实实现'

grep_file \
  'StubAppAttestService' \
  "${IOS_ROOT}/Packages/BabyCameraAccount/Sources/BabyCameraAccount/Security/StubAppAttestService.swift" \
  'StubAppAttestService stub 路径'

grep_file \
  'APP_ATTEST_ENABLED = YES' \
  "${IOS_ROOT}/BabyCamera/Resources/Config/Release.xcconfig" \
  'Release 默认开启 App Attest'

grep_file \
  'AppAttestPayload' \
  "${IOS_ROOT}/Packages/BabyCameraNetwork/Sources/BabyCameraNetwork/Security/AppAttestPayload.swift" \
  'IAP 请求 AppAttestPayload'

log "── 日志脱敏 ──"

grep_file 'LogRedactor' \
  "${IOS_ROOT}/Packages/BabyCameraNetwork/Sources/BabyCameraNetwork/Interceptors/LoggingInterceptor.swift" \
  'LoggingInterceptor 使用 LogRedactor'

grep_file 'bearerPattern' \
  "${IOS_ROOT}/Packages/BabyCameraNetwork/Sources/BabyCameraNetwork/Interceptors/LoggingInterceptor.swift" \
  'LogRedactor 脱敏 Bearer Token'

grep_file 'phonePattern' \
  "${IOS_ROOT}/Packages/BabyCameraNetwork/Sources/BabyCameraNetwork/Interceptors/LoggingInterceptor.swift" \
  'LogRedactor 脱敏手机号'

grep_file 'appleSub' \
  "${IOS_ROOT}/Packages/BabyCameraNetwork/Sources/BabyCameraNetwork/Interceptors/LoggingInterceptor.swift" \
  'LogRedactor 脱敏 appleSub'

grep_file 'FeedbackLogRedactor' \
  "${IOS_ROOT}/Packages/BabyCameraSettings/Sources/BabyCameraSettings/Services/FeedbackLogRedactor.swift" \
  'FeedbackLogRedactor 存在'

grep_file 'appleSub' \
  "${IOS_ROOT}/Packages/BabyCameraSettings/Sources/BabyCameraSettings/Services/FeedbackLogRedactor.swift" \
  'FeedbackLogRedactor 脱敏 appleSub'

log "── 硬编码密钥扫描 ──"

# Bearer JWT 字面量（排除测试 mock 中的短占位符）
grep_repo \
  'Bearer eyJ[A-Za-z0-9_-]{10,}' \
  '无硬编码 Bearer JWT' \
  'Tests/|tests/|Mock|mock|TestFixtures|REDACTED'

# Stripe / 通用 secret key
grep_repo \
  'sk_(live|test)_[A-Za-z0-9]{10,}' \
  '无硬编码 Stripe secret key' \
  ''

# 长 access token 字面量（生产代码）
PROD_TOKEN_HITS=$(grep -rE '"accessToken"\s*:\s*"[A-Za-z0-9_-]{24,}"' "${IOS_ROOT}/Packages" \
  --include='*.swift' 2>/dev/null \
  | grep -vE 'Tests/|Mock|mock|REDACTED|secret-|tok_|TestFixtures' || true)
if [[ -z "${PROD_TOKEN_HITS}" ]]; then
  pass '生产 Swift 代码无长 accessToken 字面量'
else
  fail '生产 Swift 代码含长 accessToken 字面量'
  echo "${PROD_TOKEN_HITS}" | head -10 >&2
fi

log "── 审计模板 ──"

grep_file 'T7.8' \
  "${REPO_ROOT}/docs/qa/SECURITY_AUDIT_REPORT_TEMPLATE.md" \
  'SECURITY_AUDIT_REPORT_TEMPLATE.md 存在'

log "── 汇总 ──"
log "PASS=${PASS} FAIL=${FAIL} WARN=${WARN}"

if [[ "${FAIL}" -gt 0 ]]; then
  log "SECURITY CHECKLIST FAILED"
  exit 1
fi

log "SECURITY CHECKLIST PASSED"
exit 0
