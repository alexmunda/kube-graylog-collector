REPO = alexmunda/kube-graylog-collector
TAG = 0.0.1

all: release

release: build
	docker push $(REPO):$(TAG)

build:
	docker build -t $(REPO):$(TAG) .
