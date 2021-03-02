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

source _assertions.sh

declare -A networks=(
["euu"]="10.0.3.0/24"
["sgi"]="10.0.1.0/24"
["s1u"]="172.21.0.0/24"
["s1c"]="172.21.1.0/24"
["s11"]="172.22.0.0/24"
["s5u"]="172.25.0.0/24"
["s5c"]="172.25.1.0/24"
)

declare -A apps=(
["euu"]="enb-euu"
["sgi"]="http-server-sgi"
["s1u"]="sgw-s1u"
["s1c"]="mme-s1c"
["s11"]="sgw-s11"
["s5u"]="pgw-s5u"
["s5c"]="pgw-s5c"
)

info "Validating NSM helm charts"
assert_helm_chart_installed nsm

info "Validating NSM admission webhook"
assert_service_exists nsm-admission-webhook-svc default
assert_deployment_exists nsm-admission-webhook default
assert_deployment_readiness nsm-admission-webhook default

info "Validating NSM manager"
assert_daemonset_exists nsmgr default
assert_daemonset_readiness nsmgr default

info "Validating NSM VPP forwarder"
assert_daemonset_exists nsm-vpp-forwarder default
assert_daemonset_readiness nsm-vpp-forwarder default

info "Validating Multiple networks"
newgrp docker <<EONG
docker pull busybox:stable
kind load docker-image busybox:stable --name k8s
EONG

info "Creating NSM endpoint"
annotations=" "
for net in "${!networks[@]}"; do
    annotations+="{\"link\": \"$net\", \"labels\": \"app=${apps[$net]}\",\"ipaddress\": \"${networks[$net]}\"},"
done
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: endpoint
  annotations:
    ns.networkservicemesh.io/endpoints: |
      {
        "name": "lte-network",
        "networkServices": [
          ${annotations::-1}
        ]
      }
spec:
  containers:
    - name: sidecar
      image: gwtester/nse:0.0.1
      resources:
        limits:
          networkservicemesh.io/socket: 1
      volumeMounts:
        - name: nsm-endpoints
          mountPath: /etc/nsminfo
    - image: busybox:stable
      name: instance
      command:
        - sleep
      args:
        - infinity
  volumes:
    - name: nsm-endpoints
      downwardAPI:
        items:
          - path: endpoints
            fieldRef:
              fieldPath: metadata.annotations['ns.networkservicemesh.io/endpoints']
EOF
trap "kubectl delete pod endpoint --ignore-not-found" EXIT
kubectl wait --for=condition=ready pods endpoint --timeout=3m
info "NSM Endpoint's annotations"
kubectl get pods endpoint -o jsonpath='{.metadata.annotations.ns\.networkservicemesh\.io\/endpoints}'
assert_equals "$(kubectl get networkserviceendpoints.networkservicemesh.io --no-headers | grep -c lte-network)" "${#networks[@]}"

info "Creating NSE Client"
annotations=" "
for net in "${!networks[@]}"; do
    annotations+="lte-network/${net}1?link=$net,"
done
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: client
  annotations:
    ns.networkservicemesh.io: ${annotations::-1}
spec:
  containers:
    - image: busybox:stable
      name: instance
      command:
        - sleep
      args:
        - infinity
EOF
# NOTE: Client must be destroyed first, and endpoint requires grace period to release endpoints
trap "kubectl delete pod client --ignore-not-found --now; kubectl delete pod endpoint --ignore-not-found" EXIT
kubectl wait --for=condition=ready pods client --timeout=3m
info "NSM Client's annotations"
kubectl get pods client -o jsonpath='{.metadata.annotations.ns\.networkservicemesh\.io}'

for net in "${!networks[@]}"; do
    assert_contains "$(kubectl exec client -c instance -- ip link)" "${net}1"
done
for net in "${!networks[@]}"; do
    assert_contains "$(kubectl exec client -c instance -- ip address)" "${networks[$net]%.*}"
    assert_contains "$(kubectl exec endpoint -c sidecar -- ip address)" "${networks[$net]%.*}"
done
