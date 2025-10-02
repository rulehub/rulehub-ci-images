# RuleHub CI Images - Local Build Makefile
# Mirrors _oss/_ci_images/tmp-remote-build.sh behavior for local builds.

SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c

# Auto-load .env from repo root if present
ifneq (,$(wildcard .env))
include .env
export
endif

# Config (env overrides respected)
ORG ?= rulehub
REG ?= ghcr.io/$(ORG)

BASE_REF ?= latest
POLICY_REF ?= latest
CHARTS_REF ?= latest
FRONTEND_REF ?= latest

# Build contexts: default to this repository
IMAGES_REPO ?= $(CURDIR)

# Derived image tags
TAG_BASE := $(REG)/ci-base:$(BASE_REF)
TAG_BASE_RULEHUB := $(REG)/ci-base-rulehub:$(BASE_REF)
TAG_POLICY := $(REG)/ci-policy:$(POLICY_REF)
TAG_CHARTS := $(REG)/ci-charts:$(CHARTS_REF)
TAG_FRONTEND := $(REG)/ci-frontend:$(FRONTEND_REF)

LOG_DIR := logs

.PHONY: help print-config verify-repo docker-versions \
        build base policy charts frontend \
        push push-base push-policy push-charts push-frontend \
        images clean

help:
	@echo "RuleHub CI Images - Local Build"
	@echo
	@echo "Variables (env or .env overridable):"
	@echo "  ORG           (default: $(ORG))"
	@echo "  REG           (default: $(REG))"
	@echo "  BASE_REF      (default: $(BASE_REF))"
	@echo "  POLICY_REF    (default: $(POLICY_REF))"
	@echo "  CHARTS_REF    (default: $(CHARTS_REF))"
	@echo "  FRONTEND_REF  (default: $(FRONTEND_REF))"
	@echo "  IMAGES_REPO   (default: $(IMAGES_REPO))"
	@echo
	@echo "Targets: build, base, policy, charts, frontend, push, images, docker-versions, print-config, clean"

print-config:
	@echo ORG=$(ORG)
	@echo REG=$(REG)
	@echo BASE_REF=$(BASE_REF)
	@echo POLICY_REF=$(POLICY_REF)
	@echo CHARTS_REF=$(CHARTS_REF)
	@echo FRONTEND_REF=$(FRONTEND_REF)
	@echo IMAGES_REPO=$(IMAGES_REPO)
	@echo TAG_BASE=$(TAG_BASE)
	@echo TAG_POLICY=$(TAG_POLICY)
	@echo TAG_CHARTS=$(TAG_CHARTS)
	@echo TAG_FRONTEND=$(TAG_FRONTEND)

verify-repo:
	@mkdir -p "$(LOG_DIR)"
	@if [ ! -d "$(IMAGES_REPO)/base" ] || [ ! -d "$(IMAGES_REPO)/policy" ] || \
		 [ ! -d "$(IMAGES_REPO)/charts" ] || [ ! -d "$(IMAGES_REPO)/frontend" ]; then \
		echo "[local-build] ERROR: Expected subdirs base/, policy/, charts/, frontend/ under $(IMAGES_REPO)" >&2; \
		exit 1; \
	fi

docker-versions:
	@echo "=== docker versions ===" | tee "$(LOG_DIR)/docker-versions.log"
	@{ docker --version || true; docker buildx version || true; } | tee -a "$(LOG_DIR)/docker-versions.log"

# Aggregate build
build: base policy charts frontend

# Individual builds
base: verify-repo
	@mkdir -p "$(LOG_DIR)"
	@printf "\n=== Build base ===\n" | tee "$(LOG_DIR)/build-base.log"
	# Build base using the base/ directory as the build context so the
	# Dockerfile can COPY scripts/ relative to the context (see comment in
	# base/Dockerfile). This keeps overlay builds using the repo root context.
	@docker build -f "$(IMAGES_REPO)/base/Dockerfile" -t "$(TAG_BASE)" "$(IMAGES_REPO)/base" 2>&1 | tee -a "$(LOG_DIR)/build-base.log"

policy: base verify-repo
	@mkdir -p "$(LOG_DIR)"
	@printf "\n=== Build policy ===\n" | tee "$(LOG_DIR)/build-policy.log"
	@docker build \
		--build-arg BASE_REF="$(TAG_BASE)" \
		-f "$(IMAGES_REPO)/policy/Dockerfile" \
		-t "$(TAG_POLICY)" "$(IMAGES_REPO)" 2>&1 | tee -a "$(LOG_DIR)/build-policy.log"

charts: base verify-repo
	@mkdir -p "$(LOG_DIR)"
	@printf "\n=== Build charts ===\n" | tee "$(LOG_DIR)/build-charts.log"
	@docker build \
		--build-arg BASE_REF="$(TAG_BASE)" \
		-f "$(IMAGES_REPO)/charts/Dockerfile" \
		-t "$(TAG_CHARTS)" "$(IMAGES_REPO)" 2>&1 | tee -a "$(LOG_DIR)/build-charts.log"

frontend: base verify-repo
	@mkdir -p "$(LOG_DIR)"
	@printf "\n=== Build frontend ===\n" | tee "$(LOG_DIR)/build-frontend.log"
	@docker build \
		--build-arg BASE_REF="$(TAG_BASE)" \
		-f "$(IMAGES_REPO)/frontend/Dockerfile" \
		-t "$(TAG_FRONTEND)" "$(IMAGES_REPO)" 2>&1 | tee -a "$(LOG_DIR)/build-frontend.log"

# Push helpers
push: push-base push-policy push-charts push-frontend

push-base:
	@docker push "$(TAG_BASE)"

push-policy:
	@docker push "$(TAG_POLICY)"

push-charts:
	@docker push "$(TAG_CHARTS)"

push-frontend:
	@docker push "$(TAG_FRONTEND)"

# List local images
images:
	@docker images | grep -E "ci-(base|policy|charts|frontend)" || true

# Build a ci-base image with repository dependencies from sibling `rulehub/` baked in.
.PHONY: base-rulehub
base-rulehub: verify-repo
	@mkdir -p "$(LOG_DIR)"
	@printf "\n=== Build base (rulehub deps baked) ===\n" | tee "$(LOG_DIR)/build-base-rulehub.log"
	# Build must use a context that includes the sibling rulehub/ directory so
	# the Dockerfile can COPY rulehub/requirements*. We assume IMAGES_REPO is the
	# repo root containing the base/ and the sibling rulehub/ directory.
	# Use parent directory as build context so sibling `rulehub/` is available
	@docker build --build-arg BASE_REF="$(TAG_BASE)" -f "$(IMAGES_REPO)/base/Dockerfile.rulehub" -t "$(TAG_BASE_RULEHUB)" "$(IMAGES_REPO)/.." 2>&1 | tee -a "$(LOG_DIR)/build-base-rulehub.log"

.PHONY: push-base-rulehub
push-base-rulehub:
	@docker push "$(TAG_BASE_RULEHUB)"

clean:
	@rm -rf "$(LOG_DIR)"
	@echo "Cleaned logs/"
