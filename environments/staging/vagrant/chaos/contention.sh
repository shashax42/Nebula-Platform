#!/usr/bin/env bash
# 자원 경합: 노드에서 CPU/메모리를 점유해 같은 노드 파드의 지연이 어떻게 변하는지 본다 (noisy neighbor)
#   ./chaos/contention.sh <node> <cpu_workers> <seconds> [mem_mb]
source "$(dirname "$0")/_lib.sh"
node="${1:?node}"; cpu="${2:?cpu_workers}"; secs="${3:?seconds}"; mem="${4:-0}"
require_node "$node"
args="--cpu ${cpu} --timeout ${secs}s"
[ "$mem" -gt 0 ] && args="$args --vm 1 --vm-bytes ${mem}M"
on_node "$node" "nohup sudo stress-ng ${args} >/tmp/stress.log 2>&1 &"
echo "✓ $node: stress-ng ${args}"
