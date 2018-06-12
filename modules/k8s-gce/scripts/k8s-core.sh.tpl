#!/bin/bash -xe

# install nginx for mig health check
apt-get update && apt-get install -y nginx

# Drop in config for kubenet and cloud provider
mkdir -p /etc/systemd/system/kubelet.service.d
cat > /etc/systemd/system/kubelet.service.d/20-gcenet.conf <<EOF
[Service]
Environment="KUBELET_NETWORK_ARGS=--network-plugin=cni --cni-conf-dir=/etc/cni/net.d --cni-bin-dir=/opt/cni/bin"
Environment="KUBELET_DNS_ARGS=--cluster-dns=${dns_ip} --cluster-domain=cluster.local"
Environment="KUBELET_EXTRA_ARGS=--cloud-provider=gce --container-runtime=remote --runtime-request-timeout=15m --container-runtime-endpoint=unix:///var/run/crio/crio.sock"
EOF

mkdir -p /etc/kubernetes
cat <<'EOF' > /etc/kubernetes/gce.conf
[global]
multizone = true
node-tags = ${tags}
node-instance-prefix = ${instance_prefix}
network-project-id = ${project_id}
network-name = ${network_name}
subnetwork-name = ${subnetwork_name}
${gce_conf_add}
EOF
cp /etc/kubernetes/gce.conf /etc/gce.conf

# kubeadm 1.8 workaround for https://github.com/kubernetes/release/issues/406
mkdir -p /etc/kubernetes/pki
cp /etc/kubernetes/gce.conf /etc/kubernetes/pki/gce.conf

# for GLBC
touch /var/log/glbc.log

systemctl daemon-reload

# networking setup
sudo modprobe br_netfilter
sudo sysctl net.bridge.bridge-nf-call-iptables=1
sudo sysctl net.ipv4.ip_forward=1
