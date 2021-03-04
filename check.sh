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

info "Validating Kubernetes nodes..."
assert_non_empty "$(kubectl get nodes --no-headers)"
for node in $(kubectl get node -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'); do
    kubectl wait --for=condition=ready "node/$node" --timeout=3m
done
info "Validating that MutatingAdmissionController is enabled"
assert_non_empty "$(kubectl api-versions | grep admissionregistration.k8s.io)"
assert_contains "$(kubectl api-versions)" "admissionregistration.k8s.io/v1"

if [ "${MULTI_CNI}" != "nsm" ]; then
    ./overlay/check.sh
fi
./cni-multiplexer/"${MULTI_CNI}"/check.sh
