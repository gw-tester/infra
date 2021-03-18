#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c)
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -o pipefail
set -o errexit
set -o nounset
if [[ "${DEBUG:-false}" == "true" ]]; then
    set -o xtrace
fi

source global.env
source _commons.sh

trap exit_trap ERR

info "Running deployment process..."

# Deploy Kubernetes Cluster
if ! sudo "$(command -v kind)" get clusters | grep -e k8s; then
    sudo kind create cluster --name k8s --config=./kind-config.yml --wait=300s
    sudo chown -R "$USER" "$HOME/.kube/"
fi
for node in $(kubectl get node -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'); do
    kubectl wait --for=condition=ready "node/$node" --timeout=3m
done
kubectl taint node k8s-control-plane node-role.kubernetes.io/master:NoSchedule-

# NOTE: DANM does not support chaining together multiple CNI plugin
if [ "${MULTI_CNI}" == "danm" ]; then
    for container in $(sudo docker ps -q --filter ancestor=kindest/node:v1.18.2); do
        sudo docker cp "$container:/etc/cni/net.d/10-kindnet.conflist" /tmp/10-kindnet.conflist
        jq '. | { name: .name, cniVersion: .cniVersion, type: .plugins[0].type, ipMasq: .plugins[0].ipMasq, ipam: .plugins[0].ipam }' /tmp/10-kindnet.conflist > /tmp/kindnet.conf
        sudo docker cp /tmp/kindnet.conf "$container:/etc/cni/net.d/kindnet.conf"
        sudo docker exec "$container" rm /etc/cni/net.d/10-kindnet.conflist
    done
fi

# Wait for CoreDNS service
kubectl rollout status deployment/coredns -n kube-system

# Create Multiple Networks
if [ "${MULTI_CNI}" != "nsm" ]; then
    pushd overlay
    kubectl apply -f flannel_rbac.yml
    ./deploy.sh
    popd
fi

# Deploy Multiplexer CNI services
pushd cni-multiplexer/"${MULTI_CNI}"
./deploy.sh
popd

# Wait for CNI services
for daemonset in $(kubectl get daemonset -n kube-system -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'); do
    kubectl rollout status "daemonset/$daemonset" -n kube-system
done
