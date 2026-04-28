BITCOIN_VERSION ?= 31.0
ARCH 			?= $(shell uname -m)
IMAGE_NAME      ?= bitcoin-core
REGISTRY		?= # example: ghcr.io/jonasbjork/bitcoin-core
TAG             ?= $(BITCOIN_VERSION)
CONTAINER_RT	?= docker

ifeq ($(ARCH),x86_64)
    PLATFORM := linux/amd64
else ifeq ($(ARCH),aarch64)
    PLATFORM := linux/arm64
else ifeq ($(ARCH),arm64) # macOS presents its ARM architecture as "arm64"
    PLATFORM := linux/arm64
	ARCH     := aarch64
else
    $(error Invalid architecture: $(ARCH) - only x86_64, aarch64, and arm64 are allowed.)
endif

ifdef REGISTRY
	FULL_IMAGE_NAME := $(REGISTRY)/$(IMAGE_NAME)
else
	FULL_IMAGE_NAME := $(IMAGE_NAME)
endif

.PHONY: build check-no-change push clean lint help

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*##"}; {printf "  %-15s %s\n", $$1, $$2}'

check-no-change: ## Check that bitcoin.conf is configured correctly and not left with placeholders
	@if [ ! -f bitcoin.conf ]; then \
		echo "Error: bitcoin.conf is missing"; exit 1; \
	fi
	@if grep -q "CHANGE_ME_TO_SOMETHING_SECURE" bitcoin.conf; then \
		echo "Error: Placeholder remains in bitcoin.conf — change before build."; \
		exit 1; \
	fi

lint: ## Lint the Dockerfile using hadolint
	$(CONTAINER_RT) run --rm -i hadolint/hadolint < Dockerfile

build: check-no-change ## Build the Docker image with buildx for multi-arch support
	$(CONTAINER_RT) buildx build \
		--build-arg BITCOIN_VERSION=$(BITCOIN_VERSION) \
		--build-arg ARCH=$(ARCH) \
		--platform $(PLATFORM) \
		-t $(FULL_IMAGE_NAME):$(TAG) \
		.

push: ## Push the image to the registry with both version tag and "latest"
	$(CONTAINER_RT) tag $(FULL_IMAGE_NAME):$(TAG) $(FULL_IMAGE_NAME):latest
	$(CONTAINER_RT) push $(FULL_IMAGE_NAME):$(TAG)
	$(CONTAINER_RT) push $(FULL_IMAGE_NAME):latest

clean: ## Remove local images (both version tag and "latest")
	$(CONTAINER_RT) rmi $(FULL_IMAGE_NAME):$(TAG) 2>/dev/null || true
	$(CONTAINER_RT) rmi $(FULL_IMAGE_NAME):latest 2>/dev/null || true
