#!/usr/bin/env bash
# 将 tests/mocks 映射同步到 third-party-mocks Helm chart bundle
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SRC="${ROOT}/tests/mocks"
DST="${ROOT}/infra/k8s/charts/third-party-mocks/bundled-mappings"

MOCKS=(iap wechat ad audit ai)

rm -rf "${DST}"
mkdir -p "${DST}"

for name in "${MOCKS[@]}"; do
  cp -R "${SRC}/${name}/mappings" "${DST}/${name}"
done

echo "Synced ${#MOCKS[@]} mock mapping dirs -> ${DST}"
