# IMAGE_NAME is the full name of the container image being built.
IMAGE_NAME ?= $(notdir $(shell pwd -P))$(IMAGE_ARCH_SUFFIX):$(IMAGE_VERSION)$(addprefix -,$(SHORT_SHA))
# IMAGE_VERSION is the semver version that's tagged on the image.
IMAGE_VERSION = $(shell cat VERSION)
# SHORT_SHA is the revision that the container image was built with.
SHORT_SHA ?= $(shell git describe --abbrev=8 --always --dirty='-dev' --exclude '*' || echo "unknown")
# IMAGE_ARCH_SUFFIX is the runtime architecture designator for the container
# image, it is appended to the IMAGE_NAME unless the name is specified.
IMAGE_ARCH_SUFFIX ?= $(addprefix -,$(ARCH))
# DESTDIR is where the release artifacts will be written.
DESTDIR ?= .
# DISTFILE is the path to the dist target's output file - the container image
# tarball.
DISTFILE ?= $(subst /,,$(DESTDIR))/$(subst /,_,$(IMAGE_NAME)).tar.gz

UNAME_ARCH = $(shell uname -m)
ARCH ?= $(lastword $(subst :, ,$(filter $(UNAME_ARCH):%,x86_64:amd64 aarch64:arm64)))

# SSM_AGENT_VERSION is the SSM Agent's distributed RPM Version to install.
SSM_AGENT_VERSION ?= 3.1.1767.0

.PHONY: all build check check-ssm-agent

# Run all build tasks for this container image.
all: build check

# Create a distribution container image tarball for release.
dist: all
	@mkdir -p $(dir $(DISTFILE))
	docker save $(IMAGE_NAME) | gzip > $(DISTFILE)

# Build the container image.
build:
	DOCKER_BUILDKIT=1 docker build \
		--tag $(IMAGE_NAME) \
		--build-arg IMAGE_VERSION="$(IMAGE_VERSION)" \
		--build-arg SSM_AGENT_VERSION="$(SSM_AGENT_VERSION)" \
		-f Dockerfile . >&2

# Run checks against the container image.
check: check-ssm-agent

# Check that the SSM Agent is the expected version.
check-ssm-agent:
	docker run --rm --entrypoint /usr/bin/bash \
		$(IMAGE_NAME) \
		-c 'rpm -q amazon-ssm-agent --queryformat "%{version}\n" | grep -qFw "$(SSM_AGENT_VERSION)"' >&2

clean:
	rm -f $(DISTFILE)
