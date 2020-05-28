DOCKERFILE_VERSION=3.0.1
SWISNAP_VERSION=2.7.5.577
TAG=$(DOCKERFILE_VERSION)-$(SWISNAP_VERSION)
USER=solarwinds
REPOSITORY=solarwinds-snap-agent-docker
CURRENT_IMAGE=$(USER)/$(REPOSITORY):$(TAG)
LATEST_IMAGE=$(USER)/$(REPOSITORY):latest

.PHONY: build
build: 
	@docker build -t $(CURRENT_IMAGE) -t $(LATEST_IMAGE) --build-arg swisnap_version=$(SWISNAP_VERSION) .

.PHONY: build-test
build-test: 
	@docker build -t $(CURRENT_IMAGE) -t $(LATEST_IMAGE) --build-arg swisnap_repo=swisnap-stg  --build-arg swisnap_version=$(SWISNAP_VERSION) .

.PHONY: build-and-release-docker
build-and-release-docker: build
	@docker push $(CURRENT_IMAGE)
	@docker push $(LATEST_IMAGE)

.PHONY: test
test: build-test
	cd ./deploy/overlays/stable/daemonset && kustomize edit set image $(CURRENT_IMAGE)
	cd ./deploy/overlays/stable/deployment && kustomize edit set image $(CURRENT_IMAGE)
	cd ./deploy/overlays/stable/events-collector && kustomize edit set image $(CURRENT_IMAGE)

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