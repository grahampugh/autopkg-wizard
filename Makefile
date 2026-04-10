# Makefile for AutoPkg Wizard
# Usage:
#   make              - Debug build (.app only)
#   make release      - Release build (.app + installer .pkg), opens output folder
#   make pkg          - Build installer .pkg from existing release .app
#   make clean        - Remove build artifacts

SHELL        := /bin/bash
APP_NAME     := AutoPkgWizard
BUNDLE_ID    := com.github.grahampugh.AutoPkgWizard
INFO_PLIST   := SupportingFiles/Info.plist
VERSION      := $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$(INFO_PLIST)")

BUILD_DIR    := .build
OUTPUT_DIR   := output
RELEASE_APP  := $(BUILD_DIR)/release/$(APP_NAME).app
DEBUG_APP    := $(BUILD_DIR)/debug/$(APP_NAME).app
PKG_NAME     := $(APP_NAME)-$(VERSION).pkg
COMPONENT    := $(OUTPUT_DIR)/$(APP_NAME)-component.pkg

.PHONY: all debug release pkg clean clean-output _pkg

# Default target: debug build
all: debug

# --- Debug build -----------------------------------------------------------
debug:
	@echo "==> Building $(APP_NAME) (debug)…"
	@./build_app.sh
	@echo "==> Debug app ready: $(DEBUG_APP)"

# --- Release build + installer package -------------------------------------
release: clean-output
	@echo "==> Building $(APP_NAME) (release)…"
	@./build_app.sh release
	@echo ""
	@$(MAKE) --no-print-directory _pkg
	@echo "==> Opening output folder…"
	@open "$(OUTPUT_DIR)"

# --- Build pkg from existing release app -----------------------------------
pkg:
	@if [ ! -d "$(RELEASE_APP)" ]; then \
		echo "ERROR: Release app not found at $(RELEASE_APP)." >&2; \
		echo "       Run 'make release' first." >&2; \
		exit 1; \
	fi
	@$(MAKE) --no-print-directory _pkg
	@echo "==> Opening output folder…"
	@open "$(OUTPUT_DIR)"

# --- Internal: create the .pkg ---------------------------------------------
_pkg:
	@mkdir -p "$(OUTPUT_DIR)"
	@echo "==> Creating component package…"
	@pkgbuild \
		--component "$(RELEASE_APP)" \
		--install-location /Applications \
		--identifier "$(BUNDLE_ID)" \
		--version "$(VERSION)" \
		"$(COMPONENT)"
	@echo "==> Creating distribution installer package $(PKG_NAME)…"
	@productbuild \
		--package "$(COMPONENT)" \
		--identifier "$(BUNDLE_ID)" \
		--version "$(VERSION)" \
		"$(OUTPUT_DIR)/$(PKG_NAME)"
	@rm -f "$(COMPONENT)"
	@echo "==> Installer package ready: $(OUTPUT_DIR)/$(PKG_NAME)"

# --- Clean -----------------------------------------------------------------
clean:
	@echo "==> Cleaning all build artifacts…"
	@rm -rf "$(BUILD_DIR)" "$(OUTPUT_DIR)"
	@echo "==> Clean complete."

clean-output:
	@rm -rf "$(OUTPUT_DIR)"
