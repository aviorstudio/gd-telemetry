# Generated cookbook entrypoint. Change cookbook.toml and regenerate.
# Recipe data SHA256: 9a5a352929cb9e8adb5cee97b1c8cfb5e77a0ddb46ac9ffdfb9c6e896e9f6981
COOKBOOK_REF := 14dd4792df910b8f72ae10bf01c7e426b97b667e
COOKBOOK_RECIPE := godot-addon
COOKBOOK_ROOT ?= .artifacts/cookbook/$(COOKBOOK_REF)
COOKBOOK_TEST_SUITES := lint unit security integration
COOKBOOK_CAPABILITIES :=
COOKBOOK_EMPTY :=
COOKBOOK_SPACE := $(COOKBOOK_EMPTY) $(COOKBOOK_EMPTY)
cookbook_path = $(subst $(COOKBOOK_SPACE),\$(COOKBOOK_SPACE),$(1))
COOKBOOK_ENTRY := $(call cookbook_path,$(COOKBOOK_ROOT)/cookbook/recipes/$(COOKBOOK_RECIPE).mk)

ifeq ($(wildcard $(COOKBOOK_ENTRY)),)
.DEFAULT_GOAL := help
.PHONY: help setup
help:
	@printf '%s\n' 'make help               List implemented commands' 'make setup              Prepare pinned tools and dependencies' 'make fmt                Apply formatting' 'make build              Compile, package and validate outputs' 'make test               Run implemented test groups without building' 'make test:lint          Check formatting, code and configuration' 'make test:unit          Run isolated behavior tests' 'make test:security      Run applicable security checks' 'make test:integration   Test real component boundaries' 'make clean              Remove declared outputs; preserve retained data'
	@printf '%s\n' 'Run make setup once to fetch the pinned cookbook and prepare dependencies.'
setup:
	@mkdir -p "$(COOKBOOK_ROOT)"
	@git -C "$(COOKBOOK_ROOT)" init -q
	@git -C "$(COOKBOOK_ROOT)" fetch --quiet --depth=1 https://github.com/nicodes/tools.git "$(COOKBOOK_REF)"
	@git -C "$(COOKBOOK_ROOT)" checkout --quiet --detach "$(COOKBOOK_REF)"
	@test "$$(git -C "$(COOKBOOK_ROOT)" rev-parse HEAD)" = "$(COOKBOOK_REF)"
	@$(MAKE) --no-print-directory setup
else
include $(COOKBOOK_ENTRY)
endif
