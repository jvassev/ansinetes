#!/bin/bash

TGZ=$1

readonly K8S_DIR=k8s-bin
mkdir ${K8S_DIR} &> /dev/null

if [ -f ${K8S_DIR}/kube-apiserver ]; then
	exit 0
fi

tar vxzf $TGZ

mv -v kubernetes/server/bin/{kube-scheduler,kube-proxy,kubelet,kubectl,kube-controller-manager,kube-apiserver,hyperkube} ${K8S_DIR}

rm kubernetes -fr
