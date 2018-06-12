#!/bin/bash -xe

kubeadm join --token=${token} --discovery-token-unsafe-skip-ca-verification --cri-socket /var/run/crio/crio.sock ${master_ip}:6443

# ensure crio is restarted to it picks up CNI (so node can be marked as Ready)
# TODO: think of a better way of doing this?
sleep 5
systemctl restart crio kubelet
