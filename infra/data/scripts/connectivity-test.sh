#!/usr/bin/env bash
# Baobao 数据层端到端连通性自测
# 用法：
#   cd infra/data && cp .env.example .env
#   docker compose -f docker-compose.dev.yml up -d
#   ./scripts/connectivity-test.sh
#
# K8s 内执行时设置对应 Service 主机名：
#   POSTGRES_HOST=postgresql.dev.svc.cluster.local ./scripts/connectivity-test.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${DATA_DIR}/.env" ]]; then
  # shellcheck disable=SC1091
  set -a
  source "${DATA_DIR}/.env"
  set +a
fi

POSTGRES_HOST="${POSTGRES_HOST:-127.0.0.1}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_USER="${POSTGRES_USER:-baobao}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-REPLACE_ME_POSTGRES}"
POSTGRES_DB="${POSTGRES_DB:-baobao}"

MONGODB_HOST="${MONGODB_HOST:-127.0.0.1}"
MONGODB_PORT="${MONGODB_PORT:-27017}"
MONGODB_ROOT_USER="${MONGODB_ROOT_USER:-baobao}"
MONGODB_ROOT_PASSWORD="${MONGODB_ROOT_PASSWORD:-REPLACE_ME_MONGODB}"
MONGODB_DATABASE="${MONGODB_DATABASE:-baobao}"

REDIS_HOST="${REDIS_HOST:-127.0.0.1}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_PASSWORD="${REDIS_PASSWORD:-REPLACE_ME_REDIS}"

PASS=0
FAIL=0

log_pass() { echo "[PASS] $*"; PASS=$((PASS + 1)); }
log_fail() { echo "[FAIL] $*" >&2; FAIL=$((FAIL + 1)); }

test_postgresql() {
  echo "==> PostgreSQL ${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}"
  if command -v psql >/dev/null 2>&1; then
    if PGPASSWORD="${POSTGRES_PASSWORD}" psql \
      -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" \
      -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" \
      -c "SELECT 1 AS ok;" -tAq >/dev/null 2>&1; then
      log_pass "PostgreSQL SELECT 1"
    else
      log_fail "PostgreSQL SELECT 1"
      return
    fi
  elif command -v docker >/dev/null 2>&1; then
    if docker run --rm --network host \
      -e PGPASSWORD="${POSTGRES_PASSWORD}" \
      postgres:15-alpine \
      psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" \
      -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" \
      -c "SELECT 1 AS ok;" -tAq >/dev/null 2>&1; then
      log_pass "PostgreSQL SELECT 1 (via docker)"
    else
      log_fail "PostgreSQL SELECT 1 (via docker)"
      return
    fi
  else
    log_fail "PostgreSQL: 需要 psql 或 docker"
    return
  fi

  # 写入 / 读取 / 清理探针表
  local sql="
    CREATE TABLE IF NOT EXISTS _connectivity_probe (id INT PRIMARY KEY, checked_at TIMESTAMPTZ);
    INSERT INTO _connectivity_probe (id, checked_at) VALUES (1, NOW())
    ON CONFLICT (id) DO UPDATE SET checked_at = EXCLUDED.checked_at;
    SELECT COUNT(*) FROM _connectivity_probe WHERE id = 1;
  "
  if command -v psql >/dev/null 2>&1; then
    count=$(PGPASSWORD="${POSTGRES_PASSWORD}" psql \
      -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" \
      -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" \
      -tAq -c "${sql}" 2>/dev/null | tail -1)
  else
    count=$(docker run --rm --network host \
      -e PGPASSWORD="${POSTGRES_PASSWORD}" \
      postgres:15-alpine \
      psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" \
      -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" \
      -tAq -c "${sql}" 2>/dev/null | tail -1)
  fi
  if [[ "${count}" == "1" ]]; then
    log_pass "PostgreSQL read/write probe"
  else
    log_fail "PostgreSQL read/write probe"
  fi
}

test_mongodb() {
  echo "==> MongoDB ${MONGODB_HOST}:${MONGODB_PORT}/${MONGODB_DATABASE}"
  local uri="mongodb://${MONGODB_ROOT_USER}:${MONGODB_ROOT_PASSWORD}@${MONGODB_HOST}:${MONGODB_PORT}/${MONGODB_DATABASE}?authSource=admin"
  local js="
    const r = db.adminCommand({ ping: 1 });
    if (r.ok !== 1) quit(1);
    db._connectivity_probe.replaceOne(
      { _id: 'probe' },
      { _id: 'probe', checkedAt: new Date() },
      { upsert: true }
    );
    const doc = db._connectivity_probe.findOne({ _id: 'probe' });
    if (!doc) quit(2);
    print('ok');
  "
  if command -v mongosh >/dev/null 2>&1; then
    if out=$(mongosh "${uri}" --quiet --eval "${js}" 2>/dev/null) && [[ "${out}" == *"ok"* ]]; then
      log_pass "MongoDB ping + read/write probe"
    else
      log_fail "MongoDB ping + read/write probe"
    fi
  elif command -v docker >/dev/null 2>&1; then
    if out=$(docker run --rm --network host mongo:6 \
      mongosh "${uri}" --quiet --eval "${js}" 2>/dev/null) && [[ "${out}" == *"ok"* ]]; then
      log_pass "MongoDB ping + read/write probe (via docker)"
    else
      log_fail "MongoDB ping + read/write probe (via docker)"
    fi
  else
    log_fail "MongoDB: 需要 mongosh 或 docker"
  fi
}

test_redis() {
  echo "==> Redis ${REDIS_HOST}:${REDIS_PORT}"
  local key="_connectivity:probe"
  if command -v redis-cli >/dev/null 2>&1; then
    if redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" -a "${REDIS_PASSWORD}" --no-auth-warning ping 2>/dev/null | grep -q PONG; then
      log_pass "Redis PING"
    else
      log_fail "Redis PING"
      return
    fi
    redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" -a "${REDIS_PASSWORD}" --no-auth-warning \
      SET "${key}" "ok" EX 60 >/dev/null 2>&1 || { log_fail "Redis SET"; return; }
    val=$(redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" -a "${REDIS_PASSWORD}" --no-auth-warning \
      GET "${key}" 2>/dev/null)
    if [[ "${val}" == "ok" ]]; then
      log_pass "Redis GET/SET probe"
    else
      log_fail "Redis GET/SET probe"
    fi
  elif command -v docker >/dev/null 2>&1; then
    if docker run --rm --network host redis:7-alpine \
      redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" -a "${REDIS_PASSWORD}" --no-auth-warning ping 2>/dev/null | grep -q PONG; then
      log_pass "Redis PING (via docker)"
    else
      log_fail "Redis PING (via docker)"
      return
    fi
    docker run --rm --network host redis:7-alpine \
      redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" -a "${REDIS_PASSWORD}" --no-auth-warning \
      SET "${key}" "ok" EX 60 >/dev/null 2>&1 || { log_fail "Redis SET (via docker)"; return; }
    val=$(docker run --rm --network host redis:7-alpine \
      redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" -a "${REDIS_PASSWORD}" --no-auth-warning \
      GET "${key}" 2>/dev/null)
    if [[ "${val}" == "ok" ]]; then
      log_pass "Redis GET/SET probe (via docker)"
    else
      log_fail "Redis GET/SET probe (via docker)"
    fi
  else
    log_fail "Redis: 需要 redis-cli 或 docker"
  fi
}

main() {
  echo "Baobao data layer connectivity test"
  echo "-----------------------------------"
  test_postgresql
  test_mongodb
  test_redis
  echo "-----------------------------------"
  echo "Result: ${PASS} passed, ${FAIL} failed"
  if [[ "${FAIL}" -gt 0 ]]; then
    exit 1
  fi
  echo "All checks passed."
}

main "$@"
