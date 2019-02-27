TAG="v0.1"

build-and-release-docker:
	@docker build -t dsmiech/swisnap-agent-docker:$(TAG) .
	@docker push dsmiech/swisnap-agent-docker:$(TAG)

build-test-container:
	@docker build -t dsmiech/swisnap-agent-docker:$(TAG) --build-arg swisnap_repo=swisnap-stg .
