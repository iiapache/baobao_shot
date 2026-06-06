#!/usr/bin/env bash
# Kafka topic 收发验收脚本 — T0.5
# 用法：
#   ./infra/messaging/scripts/produce-consume-test.sh
#   KAFKA_BOOTSTRAP_SERVERS=localhost:9094 ./infra/messaging/scripts/produce-consume-test.sh
#
# 前置：本地 Kafka 已启动
#   docker compose -f infra/messaging/kafka/docker-compose.kafka.yaml up -d

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

BOOTSTRAP="${KAFKA_BOOTSTRAP_SERVERS:-localhost:9094}"
TOPICS=(ai.events iap.events feed.events credit.events)
TIMEOUT_SEC="${KAFKA_TEST_TIMEOUT_SEC:-30}"
TEST_MSG="baobao-t0.5-ping-$(date +%s)"

# 优先使用本机 kafka 客户端，否则通过 bitnami 容器执行
kafka_cmd() {
  local subcmd="$1"
  shift
  if command -v "kafka-${subcmd}.sh" &>/dev/null; then
    "kafka-${subcmd}.sh" "$@"
  elif docker ps --format '{{.Names}}' | grep -q '^baobao-kafka-local$'; then
    docker exec baobao-kafka-local "kafka-${subcmd}.sh" "$@"
  else
    echo "ERROR: 未找到 kafka-${subcmd}.sh，且容器 baobao-kafka-local 未运行" >&2
    echo "请先启动: docker compose -f infra/messaging/kafka/docker-compose.kafka.yaml up -d" >&2
    exit 1
  fi
}

wait_broker() {
  local elapsed=0
  while ! kafka_cmd broker-api-versions --bootstrap-server "$BOOTSTRAP" &>/dev/null; do
    if (( elapsed >= TIMEOUT_SEC )); then
      echo "ERROR: Kafka broker ${BOOTSTRAP} 在 ${TIMEOUT_SEC}s 内不可达" >&2
      exit 1
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  echo "OK: broker ${BOOTSTRAP} 可达"
}

ensure_topics() {
  for topic in "${TOPICS[@]}"; do
    if ! kafka_cmd topics --bootstrap-server "$BOOTSTRAP" --list 2>/dev/null | grep -qx "$topic"; then
      kafka_cmd topics --bootstrap-server "$BOOTSTRAP" \
        --create --if-not-exists --topic "$topic" --partitions 3 --replication-factor 1
      echo "OK: 创建 topic ${topic}"
    fi
  done
}

test_topic() {
  local topic="$1"
  local out_file
  out_file="$(mktemp)"

  echo "TEST: ${topic} produce → consume"
  printf '%s\n' "$TEST_MSG" | kafka_cmd console-producer \
    --bootstrap-server "$BOOTSTRAP" \
    --topic "$topic" \
    --producer-property "acks=all"

  kafka_cmd console-consumer \
    --bootstrap-server "$BOOTSTRAP" \
    --topic "$topic" \
    --from-beginning \
    --max-messages 1 \
    --timeout-ms $((TIMEOUT_SEC * 1000)) \
    >"$out_file" 2>/dev/null || true

  if grep -q "$TEST_MSG" "$out_file"; then
    echo "PASS: ${topic}"
    rm -f "$out_file"
    return 0
  fi

  echo "FAIL: ${topic} — 未收到消息 '${TEST_MSG}'" >&2
  echo "消费输出:" >&2
  cat "$out_file" >&2 || true
  rm -f "$out_file"
  return 1
}

main() {
  echo "=== T0.5 Kafka 收发验收 ==="
  echo "bootstrap: ${BOOTSTRAP}"
  echo "topics:    ${TOPICS[*]}"
  echo "repo:      ${REPO_ROOT}"
  echo

  wait_broker
  ensure_topics

  local failed=0
  for topic in "${TOPICS[@]}"; do
    if ! test_topic "$topic"; then
      failed=$((failed + 1))
    fi
  done

  echo
  if (( failed > 0 )); then
    echo "RESULT: FAIL (${failed}/${#TOPICS[@]} topics)" >&2
    exit 1
  fi
  echo "RESULT: PASS (4/4 topics)"
}

main "$@"
