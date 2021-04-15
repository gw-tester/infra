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

danm_version="v4.2.1"

pushd /tmp
echo "Create Webhook certificate"
curl -sL -o webhook-create-signed-cert.sh "https://raw.githubusercontent.com/nokia/danm/$danm_version/integration/manifests/webhook/webhook-create-signed-cert.sh"
chmod +x webhook-create-signed-cert.sh
./webhook-create-signed-cert.sh
popd

cp ~/.kube/config /tmp/kubeconfig
sed -i "s|server: .*|server: https://$(kubectl get all -o jsonpath='{.items[0].spec.clusterIP}'):443|g" /tmp/kubeconfig
for id in $(sudo docker ps -q --filter "ancestor=$(sudo docker images --filter=reference='kindest/node*' -q)"); do
    sudo docker cp 00-danm.conf "${id}:/etc/cni/net.d/"
    sudo docker exec "${id}" mkdir -p /etc/cni/net.d/danm.d/
    sudo docker cp /tmp/kubeconfig "${id}:/etc/cni/net.d/danm.d/kubeconfig"
done

rm -f ./install/deployments.yml 2> /dev/null
CA_BUNDLE=$(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
export CA_BUNDLE
envsubst <./deployments.yml.tpl > ./install/deployments.yml

# Deploy DANM CNI daemonsets and CRDs
for file in rbac crds mgmt_net; do
    kubectl apply -f "install/$file.yml"
    sleep 1
done

echo "Deploy DANM daemonsets"
cat <<EOF >./kustomization.yml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
images:
  - name: danmcni/danm-cni-plugins
    newTag: ${danm_version#v}
  - name: danmcni/webhook
    newTag: ${danm_version#v}
  - name: danmcni/svcwatcher
    newTag: ${danm_version#v}
  - name: danmcni/netwatcher
    newTag: ${danm_version#v}
resources:
  - install/daemonsets.yml
  - install/deployments.yml
EOF
kubectl apply -k ./

kubectl rollout status deployment/danm-webhook-deployment -n kube-system

# Create ClusterNetwork resources
kubectl apply -f overlay.yml
