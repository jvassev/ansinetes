#!/bin/bash

TGZ=$1

readonly K8S_DIR=k8s-bin

[ -e ${K8S_DIR}/federation-apiserver ] && exit 0

mkdir ${K8S_DIR} &> /dev/null || (rm -frv ${K8S_DIR} && mkdir ${K8S_DIR})


tar vxzf $TGZ kubernetes/server/kubernetes-server-linux-amd64.tar.gz --strip-components=2

tar vxzf kubernetes-server-linux-amd64.tar.gz  kubernetes/server/bin

mv -v kubernetes/server/bin/{kube-scheduler,kube-proxy,kubelet,kube-dns,kubectl,kube-controller-manager,kube-apiserver,hyperkube} ${K8S_DIR}
