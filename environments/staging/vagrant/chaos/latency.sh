#!/usr/bin/env bash
# 노드 간 네트워크 지연/유실 주입 (eth1 = 노드 간 통신 인터페이스)
#   ./chaos/latency.sh <node> <delay_ms> [jitter_ms] [loss_%]
# 관찰: 이 노드의 파드가 DB·Kafka·다른 서비스와 주고받는 구간의 지연 → 트레이스에서 어느 span 이 늘어나는지,
#       재시도·타임아웃이 지연을 증폭시키는지
source "$(dirname "$0")/_lib.sh"
node="${1:?node}"; delay="${2:?delay_ms}"; jitter="${3:-0}"; loss="${4:-0}"
require_node "$node"
on_node "$node" "sudo tc qdisc replace dev eth1 root netem delay ${delay}ms ${jitter}ms loss ${loss}%"
echo "✓ $node: delay=${delay}ms jitter=${jitter}ms loss=${loss}%"
