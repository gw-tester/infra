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

if [ ! -d /opt/nsm ]; then
    sudo git clone --depth 1 https://github.com/networkservicemesh/networkservicemesh /opt/nsm
    sudo chown -R "$USER:" /opt/nsm
fi
if [ ! -d /opt/nse-injector-webhook ]; then
    sudo git clone --depth 1 https://github.com/gw-tester/nse-injector-webhook /opt/nse-injector-webhook
    sudo chown -R "$USER:" /opt/nse-injector-webhook
fi

# Deploy NSM services
pushd /opt/nsm
NSM_NAMESPACE=default SPIRE_ENABLED=false INSECURE=true sudo -E make helm-install-nsm
popd

# Deploy NSE injector services
pushd /opt/nse-injector-webhook
make deploy
popd

# Wait for NSM services
for daemonset in $(kubectl get daemonset | grep nsm | awk '{print $1}'); do
    echo "Waiting for $daemonset to successfully rolled out"
    if ! kubectl rollout status "daemonset/$daemonset" --timeout=3m > /dev/null; then
        echo "The $daemonset daemonset has not started properly"
        exit 1
    fi
done
kubectl rollout status deployment/nse-sidecar-injector-webhook-deployment --timeout=3m

# Create NetworkService resources
kubectl apply -f overlay.yml
