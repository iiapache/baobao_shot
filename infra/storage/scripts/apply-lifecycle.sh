#!/usr/bin/env bash
# 应用 OSS / S3 生命周期规则 — T3.2
# 用法：
#   ./infra/storage/scripts/apply-lifecycle.sh cn   # 仅 OSS
#   ./infra/storage/scripts/apply-lifecycle.sh os   # 仅 S3
#   ./infra/storage/scripts/apply-lifecycle.sh all  # 双区
#
# 环境变量（凭据来自 Vault / CI，勿写入仓库）：
#   OSS_BUCKET_NAME, OSS_ENDPOINT
#   AWS_BUCKET_NAME, AWS_REGION
#   ALIYUN_ACCESS_KEY_ID / ALIYUN_ACCESS_KEY_SECRET（或 ossutil 配置文件）
#   AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_PROFILE

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STORAGE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

TARGET="${1:-all}"

apply_oss() {
  local bucket="${OSS_BUCKET_NAME:-baby-camera-cn}"
  local lifecycle_file="${STORAGE_DIR}/oss-cn/lifecycle-rules.xml"

  echo "==> OSS lifecycle: ${bucket}"
  if command -v ossutil &>/dev/null; then
    ossutil lifecycle --method put \
      --lifecycle-configuration-file "${lifecycle_file}" \
      "oss://${bucket}/"
    echo "OK: ossutil lifecycle applied"
  elif command -v aliyun &>/dev/null; then
    aliyun oss PutBucketLifecycle \
      --bucket "${bucket}" \
      --LifecycleConfiguration "file://${lifecycle_file}"
    echo "OK: aliyun oss PutBucketLifecycle applied"
  else
    echo "SKIP: 未安装 ossutil / aliyun CLI；请手动上传 ${lifecycle_file}" >&2
    return 2
  fi
}

apply_s3() {
  local bucket="${AWS_BUCKET_NAME:-baby-camera-os}"
  local region="${AWS_REGION:-ap-southeast-1}"
  local lifecycle_file="${STORAGE_DIR}/s3-os/lifecycle-rules.json"

  echo "==> S3 lifecycle: s3://${bucket} (${region})"
  if command -v aws &>/dev/null; then
    aws s3api put-bucket-lifecycle-configuration \
      --bucket "${bucket}" \
      --lifecycle-configuration "file://${lifecycle_file}" \
      --region "${region}"
    echo "OK: aws s3api put-bucket-lifecycle-configuration applied"
  else
    echo "SKIP: 未安装 aws CLI；请手动上传 ${lifecycle_file}" >&2
    return 2
  fi
}

main() {
  local rc=0
  case "${TARGET}" in
    cn)
      apply_oss || rc=$?
      ;;
    os)
      apply_s3 || rc=$?
      ;;
    all)
      apply_oss || rc=$?
      apply_s3 || rc=$?
      ;;
    *)
      echo "用法: $0 {cn|os|all}" >&2
      exit 1
      ;;
  esac

  if (( rc != 0 )); then
    echo "RESULT: PARTIAL (CLI 不可用或未配置凭据)" >&2
    exit "${rc}"
  fi
  echo "RESULT: OK lifecycle configs submitted"
}

main "$@"
