#!/bin/bash

TGZ=$1

readonly K8S_DIR=$2
mkdir ${K8S_DIR} &> /dev/null

if [ -f ${K8S_DIR}/hyperkube ]; then
	exit 0
fi

tar vxzf $TGZ

mv -v kubernetes/server/bin/{kubeadm,kubectl,hyperkube,kubeadm} ${K8S_DIR}

rm kubernetes -fr
