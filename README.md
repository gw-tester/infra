# Infrastructure
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![GitHub Super-Linter](https://github.com/gw-tester/infra/workflows/Lint%20Code%20Base/badge.svg)](https://github.com/marketplace/actions/super-linter)

## Summary

This project provides the infrastructure services (Kubernetes
Cluster + CNI Multiplexer) required by the GW Tester CNF. The
following CNI Multiplexers are supported:

* [Multus][1]
* [DANM][2]
* [Network Service Mesh][3]

The [LTE networks](overlay/lte-networks) folder contains Kubernetes
resources used for the creation of additional Flannel networks.

| Name | Network       | VNI |
|:-----|:--------------|:---:|
| euu  | 10.0.3.0/24   | 2   |
| sgi  | 10.0.1.0/24   | 3   |
| s1u  | 172.21.0.0/24 | 4   |
| s1c  | 172.21.1.0/24 | 5   |
| s11  | 172.22.0.0/24 | 6   |
| s5u  | 172.25.0.0/24 | 7   |
| s5c  | 172.25.1.0/24 | 8   |

## Setup

This project uses [Vagrant tool][4] for provisioning Virtual Machines
automatically. It's highly recommended to use the  `setup.sh` script
of the [bootstrap-vagrant project][5] for installing Vagrant
dependencies and plugins required for its project. The script
supports two Virtualization providers (Libvirt and VirtualBox).

    curl -fsSL http://bit.ly/initVagrant | PROVIDER=libvirt bash

Once Vagrant is installed, it's possible to deploy a kubernetes
cluster with the following instruction:

    vagrant up <multus|danm|nsm>

[1]: https://github.com/intel/multus-cni
[2]: https://github.com/nokia/danm
[3]: https://github.com/networkservicemesh/networkservicemesh
[4]: https://www.vagrantup.com/
[5]: https://github.com/electrocucaracha/bootstrap-vagrant
