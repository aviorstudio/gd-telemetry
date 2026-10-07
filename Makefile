.DEFAULT_GOAL := help
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
export PYTHONDONTWRITEBYTECODE := 1
export PATH := $(CURDIR)/.artifacts/godot/bin:$(PATH)
export GODOT_BIN ?= godot
export XDG_DATA_HOME ?= $(if $(wildcard $(CURDIR)/.artifacts/godot-data/godot),$(CURDIR)/.artifacts/godot-data,$(HOME)/.local/share)
.PHONY: help install lint test build artifact-smoke check dev stop clean
help:
	@echo 'make install  Install checksum-pinned tooling and the caller-pinned Godot engine'
	@echo 'make check    Run existing source, package, behavioral and editor-lifecycle gates'
install:
	mise trust .mise.toml
	mise install
	mise exec -- bash scripts/profile-install.sh
check:
	$(MAKE) lint
	$(MAKE) build
	$(MAKE) test
	$(MAKE) artifact-smoke
dev stop:
	@echo '$@: unsupported: this addon requires a consuming Godot project'
clean:
	python3 -c 'import shutil; [shutil.rmtree(p, ignore_errors=True) for p in (".artifacts", "dist")]'
lint:
	@echo "lint: unsupported: no dedicated source lint gate is configured"
build:
	bash scripts/profile-build.sh
test:
	bash scripts/profile-test.sh
artifact-smoke:
	bash scripts/profile-artifact-smoke.sh
