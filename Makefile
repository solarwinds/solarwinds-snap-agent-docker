DOCKERFILE_VERSION=${python3 -c "import yaml; print(yaml.load(open('versions.yml'), yaml.SafeLoader)['dockerfile'])"}
SWISNAP_VERSION=${python3 -c "import yaml; print(yaml.load(open('versions.yml'), yaml.SafeLoader)['swisnap'])"}

ifeq ($(IMAGE_BUILD_ORIGIN),)
	IMAGE_BUILD_ORIGIN="manual_build"
endif
IMAGE_BUILD_ORIGIN_TAG=${ECR_REPOSITORY_URI}:${IMAGE_BUILD_ORIGIN}

.PHONY: build
build:
	$(info "Image tag:" $(IMAGE_BUILD_ORIGIN_TAG))
	$(info "SWISNAP version:" $(SWISNAP_VERSION))
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
