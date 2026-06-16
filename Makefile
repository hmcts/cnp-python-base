.DEFAULT_GOAL := build

IMAGE_PREFIX ?= base/python
PYTHON_VERSION ?= 3.13
BASE_REGISTRY ?= hmctsprod.azurecr.io

build-distroless:
	docker buildx build --load --build-arg BASE_REGISTRY=$(BASE_REGISTRY) -t $(IMAGE_PREFIX):$(PYTHON_VERSION)-distroless distroless/

build-distroless-debug:
	docker buildx build --load --build-arg BASE_REGISTRY=$(BASE_REGISTRY) -t $(IMAGE_PREFIX):$(PYTHON_VERSION)-distroless-debug distroless-debug/

build: build-distroless build-distroless-debug

test: build
	./test/smoke-test.sh $(IMAGE_PREFIX):$(PYTHON_VERSION)-distroless
	./test/smoke-test.sh $(IMAGE_PREFIX):$(PYTHON_VERSION)-distroless-debug

# Debug image has a busybox shell; the standard distroless image does not.
run-distroless-debug:
	docker run --entrypoint sh -it --rm $(IMAGE_PREFIX):$(PYTHON_VERSION)-distroless-debug
