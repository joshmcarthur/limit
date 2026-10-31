# Static site builder: https://github.com/joshmcarthur/design-export-docs
DESIGN_EXPORT_DOCS_IMAGE ?= ghcr.io/joshmcarthur/design-export-docs:latest

SYSTEMS := Android iOS
DIST ?= dist
PORT ?= 8080

ifeq ($(shell uname -s),Linux)
DOCKER_USER_FLAGS := --user $(shell id -u):$(shell id -g)
endif

.PHONY: build serve
build:
	docker run --rm $(DOCKER_USER_FLAGS) -v "$(CURDIR):/work" -w /work \
		$(DESIGN_EXPORT_DOCS_IMAGE) build --out $(DIST) $(SYSTEMS)

serve:
	docker run --rm -p $(PORT):$(PORT) -v "$(CURDIR)/$(DIST):/site" \
		$(DESIGN_EXPORT_DOCS_IMAGE) serve --addr 0.0.0.0:$(PORT) /site
