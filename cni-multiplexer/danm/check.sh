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

info "Checking DANM daemonset"
assert_daemonset_exists danm-cni
assert_daemonset_readiness danm-cni

info "Checking DANM webhook"
assert_deployment_exists danm-webhook-deployment
assert_deployment_readiness danm-webhook-deployment
assert_service_exists danm-webhook-svc

info "Validating Multiple networks"
annotations="{\"clusterNetwork\":\"default\"},"
for net in "${!networks[@]}"; do
    annotations+="{\"clusterNetwork\":\"lte-$net\"},"
done

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: tester
  annotations:
    danm.k8s.io/interfaces: |
      [
        ${annotations::-1}
      ]
spec:
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
    assert_contains "$(kubectl exec tester -- ip link)" "$net"
done
for net in "${!networks[@]}"; do
    assert_contains "$(kubectl exec tester -- ip address)" "${networks[$net]%.*}"
done
