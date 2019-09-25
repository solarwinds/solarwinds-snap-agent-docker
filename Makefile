DOCKERFILE_VERSION="2.0.0"
SWISNAP_VERSION="2.6.4.217"
TAG="$(DOCKERFILE_VERSION)-$(SWISNAP_VERSION)"
USER="solarwinds"
REPOSITORY="solarwinds-snap-agent-docker"

build-and-release-docker:
	@docker build -t $(USER)/$(REPOSITORY):$(TAG) --build-arg swisnap_version=$(SWISNAP_VERSION) .
	@docker build -t docker-bin-$(USER)/$(REPOSITORY):$(TAG) \
		-f Dockerfile.docker_bin \
		--build-arg base_image=$(USER)/$(REPOSITORY):$(TAG) .
	@docker push $(USER)/$(REPOSITORY):$(TAG)
	@docker push $(USER)/$(REPOSITORY):$(TAG)-docker-bin

test:
	@docker build -t $(USER)/$(REPOSITORY):$(TAG) \
		--build-arg swisnap_repo=swisnap-stg \
		--build-arg swisnap_version=$(SWISNAP_VERSION) .
	@docker build -t docker-bin-$(USER)/$(REPOSITORY):$(TAG) \
		-f Dockerfile.docker_bin \
		--build-arg base_image=$(USER)/$(REPOSITORY):$(TAG) .
