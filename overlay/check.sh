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

info "Validating Flannel ETCD service"
assert_equals "$(kubectl get -n kube-system jobs.batch --no-headers | grep -c etcdctl-lte-)" "7"
assert_deployment_exists flannel-etcd
assert_service_exists flannel-etcd
assert_deployment_readiness flannel-etcd

info "Validating Flannel daemonsets"
assert_equals "$(kubectl get -n kube-system daemonsets.apps --no-headers | grep -c "lte-.*-flannel-ds")" "7"
for daemonset in $(kubectl get -n kube-system daemonsets.apps -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep "lte-.*-flannel-ds"); do
    assert_daemonset_readiness "$daemonset"
done
