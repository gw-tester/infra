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

info "Validating Multus daemonset"
assert_daemonset_exists multus-ds
assert_daemonset_readiness multus-ds

info "Validating Network Attachment definitions"
assert_equals "$(kubectl get net-attach-def --no-headers | grep -c "lte-")" "7"

info "Validating Multiple networks"
newgrp docker <<EONG
docker pull busybox:stable
kind load docker-image busybox:stable --name k8s
EONG
annotations=" "
for net in "${!networks[@]}"; do
    annotations+="{\"name\": \"lte-$net\", \"interface\": \"${net}0\"},"
done

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: tester
  annotations:
    k8s.v1.cni.cncf.io/networks: |
      [
        ${annotations::-1}
      ]
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: node-role.kubernetes.io/master
                operator: DoesNotExist
  containers:
    - name: instance
      image: busybox:stable
      command:
        - sleep
      args:
        - infinity
EOF
trap "kubectl delete pod tester --ignore-not-found --now" EXIT
kubectl wait --for=condition=ready pods tester --timeout=3m
for net in "${!networks[@]}"; do
    assert_non_empty "$(kubectl exec tester -- ip link show "${net}0")"
done
for net in "${!networks[@]}"; do
    assert_contains "$(kubectl exec tester -- ip address show "${net}0")" "${networks[$net]%.*}"
done
