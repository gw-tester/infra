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

# Load NSM images to local regitstry
for image in admission-webhook vppagent-forwarder nsmdp nsmd nsmd-k8s; do
    newgrp docker <<EONG
    docker pull networkservicemesh/$image:v0.2.0
    kind load docker-image networkservicemesh/$image:v0.2.0 --name k8s
EONG
done

# Add helm chart release repositories
if ! helm repo list | grep -e nsm; then
    helm repo add nsm https://helm.nsm.dev/
    helm repo update
fi

# Install the nsm chart
if ! helm ls | grep -e nsm; then
    helm install nsm nsm/nsm --set insecure=true
fi

# Wait for NSM services
for daemonset in $(kubectl get daemonset | grep nsm | awk '{print $1}'); do
    echo "Waiting for $daemonset to successfully rolled out"
    if ! kubectl rollout status "daemonset/$daemonset" --timeout=3m > /dev/null; then
        echo "The $daemonset daemonset has not started properly"
        exit 1
    fi
done

# TODO: Create a new repository for NSE container image

newgrp docker <<EONG
docker pull networkservicemesh/nsm-init:v0.2.0
kind load docker-image networkservicemesh/nsm-init:v0.2.0 --name k8s
EONG

# Create NetworkService resources
kubectl apply -f overlay.yml
