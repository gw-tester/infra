# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2021
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

DOCKER_CMD ?= $(shell which docker 2> /dev/null || which podman 2> /dev/null || echo docker)
IMAGE_NAME=gwtester/infra:0.0.1

.PHONY: build
build:
	sudo -E $(DOCKER_CMD) build -t $(IMAGE_NAME) .
	sudo -E $(DOCKER_CMD) image prune --force
push: build
	docker-squash $(IMAGE_NAME)
	sudo -E $(DOCKER_CMD) push $(IMAGE_NAME)

.PHONY: lint
lint:
	sudo -E $(DOCKER_CMD) run -e RUN_LOCAL=true --rm \
	-e LINTER_RULES_PATH=/ \
	-e VALIDATE_KUBERNETES_KUBEVAL=false \
	-v $$(pwd):/tmp/lint github/super-linter
