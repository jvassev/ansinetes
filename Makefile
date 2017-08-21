TAG ?= latest
IMAGE ?= jvassev/ansinetes
CONT ?= ans-cont

build:
	docker build -t $(IMAGE):$(TAG) .

shell:
	@docker run --rm --entrypoint=/bin/bash -ti $(IMAGE)

push:
	docker push $(IMAGE):$(TAG)

run: build
	@docker run --rm -ti \
      -h devmode \
	  -e DEVMODE=1 \
	  -e OUTER_USER=`id -u` \
	  -v `pwd`/_defaults/ansible:/ansinetes/ansible \
	  -v `pwd`/_defaults/bin:/ansinetes/bin \
	  -v `pwd`/ans_sec:/ansinetes/security \
	  -v `pwd`/ans_tmp:/tmp/ansible \
	  $(IMAGE):$(TAG)
