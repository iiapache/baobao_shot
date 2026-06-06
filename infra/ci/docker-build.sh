#!/usr/bin/env sh
# 使用 docker buildx 构建并推送服务镜像
# 用法: ./infra/ci/docker-build.sh --service hello --context services/hello ...
set -eu

SERVICE=""
CONTEXT="."
DOCKERFILE="Dockerfile"
REGISTRY=""
TAG="latest"
PUSH="true"
PLATFORMS="${DOCKER_PLATFORMS:-linux/amd64}"

usage() {
  cat <<'EOF'
Usage: docker-build.sh [options]

  --service NAME       服务名（镜像名后缀）
  --context PATH       构建上下文目录
  --dockerfile PATH    Dockerfile 路径
  --registry URL       镜像仓库前缀（如 registry.example.com/baobao）
  --tag TAG            镜像 tag（默认 latest）
  --push true|false    是否 push（默认 true）
  --platforms LIST     buildx 平台（默认 linux/amd64）

环境变量:
  DOCKER_PLATFORMS     覆盖 --platforms
  BUILD_ARGS           额外 build-arg，空格分隔 key=value
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --service) SERVICE="$2"; shift 2 ;;
    --context) CONTEXT="$2"; shift 2 ;;
    --dockerfile) DOCKERFILE="$2"; shift 2 ;;
    --registry) REGISTRY="$2"; shift 2 ;;
    --tag) TAG="$2"; shift 2 ;;
    --push) PUSH="$2"; shift 2 ;;
    --platforms) PLATFORMS="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [ -z "$SERVICE" ] || [ -z "$REGISTRY" ]; then
  echo "error: --service and --registry are required" >&2
  usage
  exit 1
fi

if [ ! -f "$DOCKERFILE" ]; then
  echo "error: Dockerfile not found: $DOCKERFILE" >&2
  exit 1
fi

IMAGE="${REGISTRY}/${SERVICE}:${TAG}"
LATEST="${REGISTRY}/${SERVICE}:latest"

echo ">>> buildx build: ${IMAGE}"
echo ">>> context: ${CONTEXT}, dockerfile: ${DOCKERFILE}, platforms: ${PLATFORMS}"

EXTRA_BUILD_ARGS=""
for arg in ${CI_BUILD_ARGS:-}; do
  EXTRA_BUILD_ARGS="${EXTRA_BUILD_ARGS} --build-arg ${arg}"
done

PUSH_FLAG=""
if [ "$PUSH" = "true" ]; then
  PUSH_FLAG="--push"
else
  PUSH_FLAG="--load"
fi

# shellcheck disable=SC2086
docker buildx build \
  --platform "${PLATFORMS}" \
  --file "${DOCKERFILE}" \
  --tag "${IMAGE}" \
  --tag "${LATEST}" \
  --label "org.opencontainers.image.revision=${CI_COMMIT_SHA:-local}" \
  --label "org.opencontainers.image.source=${CI_PROJECT_URL:-local}" \
  --label "baobao.io/service=${SERVICE}" \
  ${EXTRA_BUILD_ARGS} \
  ${PUSH_FLAG} \
  "${CONTEXT}"

echo ">>> image built: ${IMAGE}"
if [ -n "${CI_COMMIT_SHORT_SHA:-}" ]; then
  echo "IMAGE_${SERVICE//-/_}_TAG=${TAG}" >> "${CI_PROJECT_DIR:-.}/build.env" 2>/dev/null || true
  echo "IMAGE_${SERVICE//-/_}_URL=${IMAGE}" >> "${CI_PROJECT_DIR:-.}/build.env" 2>/dev/null || true
fi
