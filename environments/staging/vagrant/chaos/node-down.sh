#!/usr/bin/env bash
# 노드 장애: VM 을 강제로 끈다 (graceful drain 없음 = 실제 장애와 같은 조건)
#   ./chaos/node-down.sh <node>      복구: ./chaos/node-up.sh <node>
# 관찰: NotReady 판정까지 걸리는 시간, 파드 재스케줄 시간, 그동안의 에러율 (= 장애 영향 범위)
source "$(dirname "$0")/_lib.sh"
node="${1:?node}"
require_node "$node"
[ "$node" = "cp" ] && { echo "control-plane 은 끄지 않는다 (단일 cp)" >&2; exit 1; }
date -u +"down at %Y-%m-%dT%H:%M:%SZ"
(cd "$VAGRANT_DIR" && vagrant halt "$node" --force)
