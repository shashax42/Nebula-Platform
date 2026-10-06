#!/usr/bin/env bash
# 모든 노드: containerd + kubeadm/kubelet/kubectl + 실패 주입 도구(tc, stress-ng)
set -euo pipefail

: "${K8S_MINOR:?}" "${NODE_IP:?}"

swapoff -a
sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab

cat >/etc/modules-load.d/k8s.conf <<CONF
overlay
br_netfilter
sch_netem
CONF
modprobe overlay
modprobe br_netfilter
modprobe sch_netem || true

cat >/etc/sysctl.d/k8s.conf <<CONF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
CONF
sysctl --system >/dev/null

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq apt-transport-https ca-certificates curl gpg containerd iproute2 stress-ng >/dev/null

mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd

mkdir -p /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${K8S_MINOR}/deb/Release.key" | gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_MINOR}/deb/ /" >/etc/apt/sources.list.d/kubernetes.list
apt-get update -qq
apt-get install -y -qq kubelet kubeadm kubectl >/dev/null
apt-mark hold kubelet kubeadm kubectl >/dev/null

# VirtualBox 는 eth0 이 NAT 라 모든 VM 이 같은 IP 를 가진다 → kubelet 이 private_network IP 를 쓰게 고정
echo "KUBELET_EXTRA_ARGS=--node-ip=${NODE_IP}" >/etc/default/kubelet
systemctl enable --now kubelet
