DOCKERFILE_VERSION=3.0.2
SWISNAP_VERSION=2.7.5.577
TAG=$(DOCKERFILE_VERSION)-$(SWISNAP_VERSION)
USER=solarwinds
REPOSITORY=solarwinds-snap-agent-docker
CURRENT_IMAGE=$(USER)/$(REPOSITORY):$(TAG)
LATEST_IMAGE=$(USER)/$(REPOSITORY):latest

.PHONY: build
build:
	docker build -t $(CURRENT_IMAGE) -t $(LATEST_IMAGE) --build-arg swisnap_version=$(SWISNAP_VERSION) .

.PHONY: build-and-release-docker
build-and-release-docker: build
	@docker push $(CURRENT_IMAGE)
	@docker push $(LATEST_IMAGE)

.PHONY: test
test: build
	cd ./deploy/overlays/stable/daemonset && kustomize edit set image${CURRENT_IMAGE}
	cd ./deploy/overlays/stable/deployment && kustomize edit set image ${CURRENT_IMAGE}
	cd ./deploy/overlays/stable/events-collector && kustomize edit set image ${CURRENT_IMAGE}

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

.PHONY: circleci 
circleci:  ## Note: This expects you to have circleci cli installed locally
	circleci local execute --job build --job validate