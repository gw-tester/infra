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

# Load Multus image to local regitstry
newgrp docker <<EONG
docker pull nfvpe/multus:v3.4
kind load docker-image nfvpe/multus:v3.4 --name k8s
EONG

# Deploy Multus CNI daemonset and CRD
kubectl apply -f install
kubectl rollout status daemonset/multus-ds -n kube-system --timeout=3m

# Create NetworkAttachmentDefinition resources
kubectl apply -f overlay.yml
