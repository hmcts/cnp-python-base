.DEFAULT_GOAL := build

IMAGE_PREFIX ?= base/python
PYTHON_VERSION ?= 3.13
BASE_REGISTRY ?= hmctsprod.azurecr.io

# 7-day dependency cooldown for the lock (override: make lock EXCLUDE_NEWER=YYYY-MM-DD).
# Computed with python3 for macOS/Linux portability.
EXCLUDE_NEWER ?= $(shell python3 -c "import datetime; print((datetime.date.today() - datetime.timedelta(days=7)).isoformat())")

build-distroless:
	docker buildx build --load --build-arg BASE_REGISTRY=$(BASE_REGISTRY) -t $(IMAGE_PREFIX):$(PYTHON_VERSION)-distroless distroless/

build-distroless-debug:
	docker buildx build --load --build-arg BASE_REGISTRY=$(BASE_REGISTRY) -t $(IMAGE_PREFIX):$(PYTHON_VERSION)-distroless-debug distroless-debug/

build: build-distroless build-distroless-debug

test: build
	./test/smoke-test.sh $(IMAGE_PREFIX):$(PYTHON_VERSION)-distroless
	./test/smoke-test.sh $(IMAGE_PREFIX):$(PYTHON_VERSION)-distroless-debug

lock:
	docker run --rm -v "$(CURDIR)/distroless":/work -w /work python:3.13-slim-trixie \
		sh -c 'pip install --quiet uv && uv pip compile --generate-hashes --exclude-newer $(EXCLUDE_NEWER) requirements.in -o requirements.txt'
	cp distroless/requirements.in distroless-debug/requirements.in
	cp distroless/requirements.txt distroless-debug/requirements.txt
	@echo "Lock regenerated (cooldown cutoff: $(EXCLUDE_NEWER)) and synced to both variants."

# Debug image has a busybox shell; the standard distroless image does not.
run-distroless-debug:
	docker run --entrypoint sh -it --rm $(IMAGE_PREFIX):$(PYTHON_VERSION)-distroless-debug

.PHONY: build build-distroless build-distroless-debug test lock run-distroless-debug
