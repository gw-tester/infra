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

# shellcheck disable=SC2034
declare -A networks=(
["euu"]="10.0.3.0/24"
["sgi"]="10.0.1.0/24"
["s1u"]="172.21.0.0/24"
["s1c"]="172.21.1.0/24"
["s11"]="172.22.0.0/24"
["s5u"]="172.25.0.0/24"
["s5c"]="172.25.1.0/24"
)

function print_stats {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        set +o xtrace
    fi
    printf "CPU usage: "
    grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage " %"}'
    printf "Memory free(Kb): "
    awk -v low="$(grep low /proc/zoneinfo | awk '{k+=$2}END{print k}')" '{a[$1]=$2}  END{ print a["MemFree:"]+a["Active(file):"]+a["Inactive(file):"]+a["SReclaimable:"]-(12*low);}' /proc/meminfo
}

function exit_trap {
    print_stats
    echo "Environment variables:"
    echo "MULTI_CNI: $MULTI_CNI"
    echo "Docker statistics:"
    sudo docker stats --no-stream
    echo "Kubernetes Resources:"
    kubectl get all -A -o wide
    echo "Kubernetes Nodes information:"
    kubectl describe nodes
}

function info {
    _print_msg "INFO" "$1"
}

function error {
    _print_msg "ERROR" "$1"
    exit 1
}

function _print_msg {
    echo "$(date +%H:%M:%S) - $1: $2"
}
