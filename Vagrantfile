# -*- mode: ruby -*-
# vi: set ft=ruby :
##############################################################################
# Copyright (c) 2021
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

$no_proxy = ENV['NO_PROXY'] || ENV['no_proxy'] || "127.0.0.1,localhost"
(1..254).each do |i|
  $no_proxy += ",10.0.2.#{i}"
end
$debug = ENV['DEBUG'] || "true"

Vagrant.configure(2) do |config|
  config.vm.provider :libvirt
  config.vm.provider :virtualbox

  config.vm.box = "generic/ubuntu1804"
  config.vm.box_check_update = false
  config.vm.synced_folder './', '/vagrant'

  if ENV['http_proxy'] != nil and ENV['https_proxy'] != nil
    if Vagrant.has_plugin?('vagrant-proxyconf')
      config.proxy.http     = ENV['http_proxy'] || ENV['HTTP_PROXY'] || ""
      config.proxy.https    = ENV['https_proxy'] || ENV['HTTPS_PROXY'] || ""
      config.proxy.no_proxy = $no_proxy
      config.proxy.enabled = { docker: false, git: false }
    end
  end

  [:virtualbox, :libvirt].each do |provider|
  config.vm.provider provider do |p|
      p.cpus = 2
      p.memory = 6144
    end
  end

  config.vm.provider "virtualbox" do |v|
    v.gui = false
  end

  config.vm.provider :libvirt do |v|
    v.cpu_mode = 'host-passthrough'
    v.random_hostname = true
    v.management_network_address = "10.0.2.0/24"
    v.management_network_name = "administration"
  end

  # Install minimal requirements
  config.vm.provision 'shell', privileged: false, inline: <<-SHELL
    if ! command -v curl; then
        source /etc/os-release || source /usr/lib/os-release
        case ${ID,,} in
            ubuntu|debian)
                sudo apt-get update
                sudo apt-get install -y -qq -o=Dpkg::Use-Pty=0 curl
            ;;
        esac
    fi
  SHELL

  [:multus, :danm, :nsm].each do |multiplexer|
    config.vm.define multiplexer do |confignode|
      # Deploy services
      confignode.vm.provision 'shell', privileged: false do |sh|
        sh.env = {
          'DEBUG': "#{$debug}",
          'MULTI_CNI': "#{multiplexer}",
        }
        sh.inline = <<-SHELL
          set -o pipefail
          set -o errexit

          echo "export MULTI_CNI=$MULTI_CNI" | sudo tee --append /etc/environment

          cd /vagrant
          ./install.sh | tee ~/install.log
          ./deploy.sh | tee ~/deploy.log
        SHELL
      end

      # Validate services
      confignode.vm.provision 'shell', privileged: false, inline: <<-SHELL
        set -o pipefail
        set -o errexit

        source /etc/environment

        cd /vagrant
        ./check.sh | tee ~/check.log
      SHELL
    end # confignode
  end # multiplexer

end
