DOCKERFILE_VERSION="2.0.0"
SWISNAP_VERSION="2.6.0.398"
TAG="$(DOCKERFILE_VERSION)-$(SWISNAP_VERSION)"
USER="solarwinds"
REPOSITORY="solarwinds-snap-agent-docker"

build-and-release-docker:
	@docker build -t $(USER)/$(REPOSITORY):$(TAG) .
	@docker push $(USER)/$(REPOSITORY):$(TAG)

test:
	@docker build -t $(USER)/$(REPOSITORY):$(TAG) --build-arg swisnap_repo=swisnap-stg --build-arg swisnap_version=$(SWISNAP_VERSION) .
