DOCKERFILE_VERSION=3.0.1
SWISNAP_VERSION=2.7.5.577
TAG="$(DOCKERFILE_VERSION)-$(SWISNAP_VERSION)"
USER=solarwinds
REPOSITORY=solarwinds-snap-agent-docker

.PHONY: build-and-release-docker
build-and-release-docker:
	@docker build -t $(USER)/$(REPOSITORY):$(TAG) --build-arg swisnap_version=$(SWISNAP_VERSION) .
	@docker push $(USER)/$(REPOSITORY):$(TAG)
	@docker tag $(USER)/$(REPOSITORY):$(TAG) $(USER)/$(REPOSITORY):latest
	@docker push $(USER)/$(REPOSITORY):latest

.PHONY: test
test:
	docker build -t $(USER)/$(REPOSITORY):$(TAG) -t $(USER)/$(REPOSITORY):latest --build-arg swisnap_repo=swisnap-stg --build-arg swisnap_version=$(SWISNAP_VERSION) .

.PHONY: deploy-daemonset
deploy-daemonset:
	kubectl apply -k ./deploy/base/daemonset

.PHONY: delete-daemonset
delete-daemonset:
	kubectl delete -k ./deploy/base/daemonset

.PHONY: deploy-deployment
deploy-deployment:
	kubectl apply -k ./deploy/base/deployment

.PHONY: delete-deployment
delete-deployment:
	kubectl delete -k ./deploy/base/deployment