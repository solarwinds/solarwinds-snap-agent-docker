ifeq ($(IMAGE_BUILD_ORIGIN),)
	IMAGE_BUILD_ORIGIN="manual_build"
endif

ifeq ($(ECR_REPOSITORY_URI),)
	IMAGE_BUILD_ORIGIN_TAG="manual_build"
else
	IMAGE_BUILD_ORIGIN_TAG=${ECR_REPOSITORY_URI}:${IMAGE_BUILD_ORIGIN}
endif


.PHONY: build
build: get-versions
	@docker build -t $(IMAGE_BUILD_ORIGIN_TAG) --build-arg swisnap_version=$(SWISNAP_VERSION) .

.PHONY: test
test: build-test
	cd ./deploy/overlays/stable/daemonset && kustomize edit set image $(IMAGE_BUILD_ORIGIN_TAG)
	cd ./deploy/overlays/stable/deployment && kustomize edit set image $(IMAGE_BUILD_ORIGIN_TAG)
	cd ./deploy/overlays/stable/events-collector && kustomize edit set image $(IMAGE_BUILD_ORIGIN_TAG)

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

.PHONY: get-versions
get-versions:
	$(eval DOCKERFILE_VERSION := $(shell . $$PWD/versions.env && echo $$DOCKERFILE_VERSION))
	$(eval SWISNAP_VERSION := $(shell . $$PWD/versions.env && echo $$SWISNAP_VERSION))
	$(eval TAG_VERSION := $(DOCKERFILE_VERSION)_$(SWISNAP_VERSION))
	$(info DOCKERFILE version: $(DOCKERFILE_VERSION))
	$(info SWISNAP version: $(SWISNAP_VERSION))

.PHONY: update-image-version
update-image-version: get-versions
	@sed -i.bak 's/^\(.*newTag:[[:space:]]\)[0-9\.-]*/\1${TAG_VERSION}/' deploy/overlays/stable/daemonset/kustomization.yaml
	@sed -i.bak 's/^\(.*newTag:[[:space:]]\)[0-9\.-]*/\1${TAG_VERSION}/' deploy/overlays/stable/deployment/kustomization.yaml
	@sed -i.bak 's/^\(.*newTag:[[:space:]]\)[0-9\.-]*/\1${TAG_VERSION}/' deploy/overlays/stable/events-collector/kustomization.yaml
