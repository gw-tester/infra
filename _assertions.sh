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

source _commons.sh

function assert_equals {
    local input=$1
    local expected=$2

    if [ "$input" != "$expected" ]; then
        error "Go $input expected $expected"
    fi
}

function assert_contains {
    local input=$1
    local expected=$2

    if ! echo "$input" | grep -q "$expected"; then
        error "Got $input expected $expected"
    fi
}

function assert_non_empty {
    local input=$1

    if [ -z "$input" ]; then
        error "Empty input value"
    fi
}

function assert_deployment_exists {
    assert_k8s_resource_exists "deployment" "$@"
}

function assert_daemonset_exists {
    assert_k8s_resource_exists "daemonset" "$@"
}

function assert_service_exists {
    assert_k8s_resource_exists "service" "$@"
}

function assert_k8s_resource_exists {
    local resource="$1/$2"
    local namespace=${3:-kube-system}

    if [ -z "$(kubectl get "$resource" -n "$namespace" --no-headers)" ]; then
        error "$resource not exists in $namespace"
    fi
}

function assert_helm_repo_exists {
    local repo="$1"

    if ! helm repo list | grep -q "$repo"; then
        error "$repo helm repo does not exists"
    fi
}

function assert_helm_repo_exists {
    local repo="$1"

    if ! helm repo list | grep -q "$repo"; then
        error "$repo helm repo does not exists"
    fi
}

function assert_helm_chart_installed {
    local chart="$1"

    if ! helm history "$chart" | grep -q "Install complete"; then
        error "$chart helm chart installation is not complete"
    fi
}

function assert_deployment_readiness {
    local name="deployments/$1"
    local namespace=${2:-kube-system}

    ready_replicas="$(kubectl get -n "$namespace" "$name" -o=jsonpath --template='{.status.readyReplicas}')"
    replicas="$(kubectl get -n "$namespace" "$name" -o=jsonpath --template='{.status.replicas}')"

    assert_equals "$ready_replicas" "$replicas"
}

function assert_daemonset_readiness {
    local name="daemonsets/$1"
    local namespace=${2:-kube-system}

    number_ready="$(kubectl get "$name" -n "$namespace" -o=jsonpath --template='{.status.numberReady}')"
    desired_number_scheduled="$(kubectl get "$name" -n "$namespace" -o=jsonpath --template='{.status.desiredNumberScheduled}')"

    assert_equals "$number_ready" "$desired_number_scheduled"
}
