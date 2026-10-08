#!/usr/bin/env bash
# worker: control-plane 이 남긴 join 명령으로 합류
set -euo pipefail

if [ -f /etc/kubernetes/kubelet.conf ]; then
  exit 0
fi
for _ in $(seq 1 60); do
  [ -f /vagrant/.join.sh ] && break
  sleep 5
done
bash /vagrant/.join.sh
