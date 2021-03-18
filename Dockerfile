FROM ubuntu:bionic

ENV PKG "kubectl jq helm kind make docker-ce-cli"
ENV PKG_UPDATE "true"
ENV PKG_KUBECTL_VERSION "v1.20.4"
ENV PKG_KIND_VERSION "0.10.0"
ENV USER "docker"

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install -y --no-install-recommends \
  curl=7.58.0-2ubuntu3.12 \
  ca-certificates=20210119~18.04.1 \
  gnupg2=2.2.4-1ubuntu1.4 \
  sudo=1.8.21p2-3ubuntu1.4 && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

RUN echo "deb https://download.docker.com/linux/ubuntu/ bionic stable" | tee /etc/apt/sources.list.d/docker.list && \
  mkdir -p /etc/bash_completion.d && \
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -qq - && \
  groupadd -g 2000 docker && \
  useradd -m -u 2001 -g docker docker && \
  echo "docker ALL=(ALL) NOPASSWD: ALL" | tee /etc/sudoers.d/docker

USER docker
WORKDIR /home/docker

# NOTE: Shorten link -> https://github.com/electrocucaracha/pkg-mgr_scripts
RUN curl -fsSL http://bit.ly/install_pkg | bash
