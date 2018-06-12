#!/bin/bash

# install runc
wget https://github.com/opencontainers/runc/releases/download/v1.0.0-rc4/runc.amd64
chmod +x runc.amd64
mv runc.amd64 /usr/bin/runc

# install kata
sh -c "echo 'deb http://download.opensuse.org/repositories/home:/katacontainers:/release/xUbuntu_$(lsb_release -rs)/ /' > /etc/apt/sources.list.d/kata-containers.list"
curl -sL  http://download.opensuse.org/repositories/home:/katacontainers:/release/xUbuntu_$(lsb_release -rs)/Release.key | apt-key add -
apt-get update
apt-get -y install kata-runtime kata-proxy kata-shim

# install go 1.8.5
wget https://storage.googleapis.com/golang/go1.8.5.linux-amd64.tar.gz
sudo tar -xvf go1.8.5.linux-amd64.tar.gz -C /usr/local/
mkdir -p $HOME/go/src
export GOPATH=$HOME/go
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin
rm go1.8.5.linux-amd64.tar.gz

# build crictl
go get github.com/kubernetes-incubator/cri-tools/cmd/crictl
cd $GOPATH/src/github.com/kubernetes-incubator/cri-tools
make
make install

# build crio
apt-get update
apt-get install -y libglib2.0-dev libseccomp-dev libgpgme11-dev libdevmapper-dev make git
go get -d github.com/kubernetes-incubator/cri-o
cd $GOPATH/src/github.com/kubernetes-incubator/cri-o
make install.tools
make
make install
make install.config

# ensure crio config is correct
perl -i -0pe 's/\[crio.runtime\]/\[crio.runtime\]\nmanage_network_ns_lifecycle = true/' /etc/crio/crio.conf
perl -i -0pe "s/#registries = \[\n# \]/registries = ['docker.io', 'gcr.io']/" /etc/crio/crio.conf
perl -i -0pe 's/runtime_untrusted_workload = ""/runtime_untrusted_workload = "\/usr\/bin\/kata-runtime"/' /etc/crio/crio.conf
perl -i -0pe 's/default_workload_trust = "trusted"/default_workload_trust = "untrusted"/' /etc/crio/crio.conf

# enable crio
sh -c 'echo "[Unit]
Description=OCI-based implementation of Kubernetes Container Runtime Interface
Documentation=https://github.com/kubernetes-incubator/cri-o

[Service]
ExecStart=/usr/local/bin/crio --log-level debug
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/crio.service'
systemctl daemon-reload
systemctl enable crio
systemctl start crio

# install cni plugins
go get -d github.com/containernetworking/plugins
cd $GOPATH/src/github.com/containernetworking/plugins
./build.sh
mkdir -p /opt/cni/bin
cp bin/* /opt/cni/bin/

# install skopeo (this is needed to create /etc/containers/policy.json)
add-apt-repository ppa:projectatomic/ppa -y
apt-get update
apt-get install -y skopeo-containers
systemctl restart crio

# install k8s components
apt-get update && apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y kubelet kubeadm kubectl

# copy binaries
cp $GOPATH/bin/* /usr/local/bin
