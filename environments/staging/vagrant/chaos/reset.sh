#!/usr/bin/env bash
# 모든 주입 해제: netem 제거, stress-ng 종료, 꺼진 노드 기동
source "$(dirname "$0")/_lib.sh"
for n in "${NODES[@]}"; do
  if (cd "$VAGRANT_DIR" && vagrant status "$n" | grep -q running); then
    on_node "$n" "sudo tc qdisc del dev eth1 root 2>/dev/null; sudo pkill stress-ng 2>/dev/null; true"
  else
    (cd "$VAGRANT_DIR" && vagrant up "$n" --no-provision)
  fi
done
echo "✓ reset"
