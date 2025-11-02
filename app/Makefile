REGISTRY_HOST ?= localhost:5001
IMAGE_NAME = webapp
TAG ?= v1.0

.PHONY: build
build:
	docker build -t $(REGISTRY_HOST)/$(IMAGE_NAME):$(TAG) .

.PHONY: push
push:
	docker push $(REGISTRY_HOST)/$(IMAGE_NAME):$(TAG)

.PHONY: test
test:
	go test -v ./...

.PHONY: run
run:
	go run main.go

.PHONY: deps
deps:
	go mod download

.PHONY: tidy
tidy:
	go mod tidy