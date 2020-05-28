DOCKERFILE_VERSION=3.0.1
SWISNAP_VERSION=2.7.5.577
TAG=$(DOCKERFILE_VERSION)-$(SWISNAP_VERSION)
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
	cd ./deploy/overlays/stable/daemonset && kustomize edit set image $(USER)/$(REPOSITORY):$(TAG)
	cd ./deploy/overlays/stable/deployment && kustomize edit set image $(USER)/$(REPOSITORY):$(TAG)
	cd ./deploy/overlays/stable/events-collector && kustomize edit set image $(USER)/$(REPOSITORY):$(TAG)

.PHONY: deploy-daemonset
deploy-daemonset:
	kustomize build ./deploy/base/daemonset | kubectl apply -f-

.PHONY: delete-daemonset
delete-daemonset:
	kustomize build ./deploy/base/daemonset | kubectl delete -f-

.PHONY: deploy-deployment
deploy-deployment:
	kustomize build ./deploy/base/deployment | kubectl apply -f-

.PHONY: delete-deployment
delete-deployment:
	kustomize build ./deploy/base/deployment | kubectl delete -f-