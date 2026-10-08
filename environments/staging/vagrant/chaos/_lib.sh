#!/usr/bin/env bash
# 공통: 노드 이름 검증, VM 안에서 명령 실행
set -euo pipefail
VAGRANT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NODES=(cp worker-1 worker-2)

require_node() {
  local n="$1"
  for x in "${NODES[@]}"; do [ "$x" = "$n" ] && return 0; done
  echo "알 수 없는 노드: $n (가능: ${NODES[*]})" >&2
  exit 1
}

on_node() {
  local n="$1"; shift
  (cd "$VAGRANT_DIR" && vagrant ssh "$n" -c "$*")
}
