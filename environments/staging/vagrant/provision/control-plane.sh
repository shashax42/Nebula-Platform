#!/usr/bin/env bash
# control-plane: kubeadm init + Flannel CNI. worker 가 쓸 join 명령을 /vagrant/.join.sh 로 남긴다
set -euo pipefail

: "${NODE_IP:?}"
POD_CIDR="10.244.0.0/16"

if [ ! -f /etc/kubernetes/admin.conf ]; then
  kubeadm init --apiserver-advertise-address="${NODE_IP}" --pod-network-cidr="${POD_CIDR}" --node-name cp
fi

mkdir -p /home/vagrant/.kube
cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube
cp /etc/kubernetes/admin.conf /vagrant/.kubeconfig
export KUBECONFIG=/etc/kubernetes/admin.conf

# Flannel: VM 간 통신은 eth1(private_network) 으로
curl -fsSL https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml \
  | sed 's#- --kube-subnet-mgr#- --kube-subnet-mgr\n        - --iface=eth1#' \
  | kubectl apply -f -

kubeadm token create --print-join-command >/vagrant/.join.sh
chmod +x /vagrant/.join.sh
