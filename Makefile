DOCKERFILE_VERSION="2.1.0"
SWISNAP_VERSION="2.6.4.217"
TAG="$(DOCKERFILE_VERSION)-$(SWISNAP_VERSION)"
USER="solarwinds"
REPOSITORY="solarwinds-snap-agent-docker"

build-and-release-docker:
	@docker build -t $(USER)/$(REPOSITORY):$(TAG) --build-arg swisnap_version=$(SWISNAP_VERSION) .
	@docker push $(USER)/$(REPOSITORY):$(TAG)
	@docker tag $(USER)/$(REPOSITORY):$(TAG) $(USER)/$(REPOSITORY):latest
	@docker push $(USER)/$(REPOSITORY):latest

test:
	@docker build -t $(USER)/$(REPOSITORY):$(TAG) --build-arg swisnap_repo=swisnap-stg --build-arg swisnap_version=$(SWISNAP_VERSION) .
