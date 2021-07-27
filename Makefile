DOCKERFILE_VERSION=4.3.0

ifeq ($(SWISNAP_VERSION),)
	SWISNAP_VERSION=4.1.0.1024
endif
ifeq ($(IMAGE_BUILD_ORIGIN),)
	IMAGE_BUILD_ORIGIN="manual_build"
endif
TAG=$(DOCKERFILE_VERSION)-$(SWISNAP_VERSION)
USER=solarwinds
REPOSITORY=solarwinds-snap-agent-docker
CURRENT_IMAGE=$(USER)/$(REPOSITORY):$(TAG)
LATEST_IMAGE=$(USER)/$(REPOSITORY):latest
LATEST_ECR_TAG=${ECR_REPOSITORY_URI}:latest
IMAGE_BUILD_ORIGIN_TAG=${ECR_REPOSITORY_URI}:${IMAGE_BUILD_ORIGIN}

.PHONY: build
build: 
	@docker build -t $(IMAGE_BUILD_ORIGIN_TAG) --build-arg swisnap_version=$(SWISNAP_VERSION) .

.PHONY: build-test
build-test: 
	@docker build -t $(CURRENT_IMAGE) -t $(LATEST_IMAGE) -t ${LATEST_ECR_TAG} --build-arg swisnap_repo=swisnap-stg --build-arg swisnap_version=$(SWISNAP_VERSION) .

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
	kubectl apply -k ./deploy/base/daemonset

.PHONY: delete-daemonset
delete-daemonset:
	kubectl delete -k ./deploy/base/daemonset

.PHONY: deploy-deployment
deploy-deployment:
	kubectl apply -k ./deploy/base/deployment

.PHONY: delete-deployment
delete-deployment:
	kustomize delete -k ./deploy/base/deployment

.PHONY: circleci 
circleci:  ## Note: This expects you to have circleci cli installed locally
	circleci local execute --job build --job validate
