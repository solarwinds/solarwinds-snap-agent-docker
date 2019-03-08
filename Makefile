TAG="1.1.0"
USER="solarwinds"
REPOSITORY="solarwinds-snap-agent-docker"

build-and-release-docker:
	@docker build -t $(USER)/$(REPOSITORY):$(TAG) .
	@docker push $(USER)/$(REPOSITORY):$(TAG)

test:
	@docker build -t $(USER)/$(REPOSITORY):$(TAG) --build-arg swisnap_repo=swisnap-stg .
