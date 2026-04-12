# Makefile for AutoPkg Wizard
# Usage:
#   make              - Debug build (.app only)
#   make release      - Release build (.app + .pkg + .dmg + GitHub pre-release)
#   make pkg          - Build installer .pkg from existing release .app
#   make dmg          - Build distributable .dmg from existing release .app
#   make github       - Create/update GitHub pre-release from existing .pkg and .dmg
#   make clean        - Remove build artifacts

SHELL        := /bin/bash
APP_NAME     := AutoPkgWizard
BUNDLE_ID    := com.github.grahampugh.AutoPkgWizard
INFO_PLIST   := SupportingFiles/Info.plist
VERSION      := $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$(INFO_PLIST)")
TAG          := v$(VERSION)

BUILD_DIR    := .build
OUTPUT_DIR   := output
RELEASE_APP  := $(BUILD_DIR)/release/$(APP_NAME).app
DEBUG_APP    := $(BUILD_DIR)/debug/$(APP_NAME).app
PKG_NAME     := $(APP_NAME)-$(VERSION).pkg
PKG_PATH     := $(OUTPUT_DIR)/$(PKG_NAME)
COMPONENT    := $(OUTPUT_DIR)/$(APP_NAME)-component.pkg
DMG_NAME     := $(APP_NAME)-$(VERSION).dmg
DMG_PATH     := $(OUTPUT_DIR)/$(DMG_NAME)
DMG_STAGING  := $(OUTPUT_DIR)/dmg-staging

.PHONY: all debug release pkg dmg github clean clean-output _pkg _dmg

# Default target: debug build
all: debug

# --- Debug build -----------------------------------------------------------
debug:
	@echo "==> Building $(APP_NAME) (debug)…"
	@./build_app.sh
	@echo "==> Debug app ready: $(DEBUG_APP)"

# --- Release build + installer package + dmg + GitHub release --------------
release: clean-output
	@echo "==> Building $(APP_NAME) (release)…"
	@./build_app.sh release
	@echo ""
	@$(MAKE) --no-print-directory _pkg
	@echo ""
	@$(MAKE) --no-print-directory _dmg
	@echo ""
	@$(MAKE) --no-print-directory github
	@echo ""
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

# --- Build dmg from existing release app -----------------------------------
dmg:
	@if [ ! -d "$(RELEASE_APP)" ]; then \
		echo "ERROR: Release app not found at $(RELEASE_APP)." >&2; \
		echo "       Run 'make release' first." >&2; \
		exit 1; \
	fi
	@$(MAKE) --no-print-directory _dmg
	@echo "==> Opening output folder…"
	@open "$(OUTPUT_DIR)"

# --- Create / update GitHub pre-release ------------------------------------
github:
	@if [ ! -f "$(PKG_PATH)" ] && [ ! -f "$(DMG_PATH)" ]; then \
		echo "ERROR: Neither $(PKG_PATH) nor $(DMG_PATH) found." >&2; \
		echo "       Run 'make release' first." >&2; \
		exit 1; \
	fi
	@echo "==> Preparing GitHub pre-release $(TAG)…"
	@# Ensure all changes are committed
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "WARNING: Uncommitted changes detected. Committing…"; \
		git add -A && git commit -m "Release $(VERSION)"; \
	fi
	@# Delete existing release for this tag (if any)
	@if gh release view "$(TAG)" >/dev/null 2>&1; then \
		echo "==> Deleting existing release $(TAG)…"; \
		gh release delete "$(TAG)" --cleanup-tag --yes; \
		git tag -d "$(TAG)" 2>/dev/null || true; \
	fi
	@# Create the pre-release with the .pkg attached
	@echo "==> Creating GitHub pre-release $(TAG)…"
	@git tag "$(TAG)"
	@git push origin "$(TAG)"
	@gh release create "$(TAG)" \
		$(if $(wildcard $(PKG_PATH)),"$(PKG_PATH)#$(PKG_NAME)") \
		$(if $(wildcard $(DMG_PATH)),"$(DMG_PATH)#$(DMG_NAME)") \
		--title "$(APP_NAME) $(VERSION)" \
		--prerelease \
		--generate-notes
	@echo "==> GitHub pre-release $(TAG) created."

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
		"$(PKG_PATH)"
	@rm -f "$(COMPONENT)"
	@echo "==> Installer package ready: $(PKG_PATH)"

# --- Internal: create the .dmg ----------------------------------------------
_dmg:
	@mkdir -p "$(OUTPUT_DIR)"
	@rm -rf "$(DMG_STAGING)"
	@mkdir -p "$(DMG_STAGING)"
	@echo "==> Preparing DMG contents…"
	@cp -R "$(RELEASE_APP)" "$(DMG_STAGING)/$(APP_NAME).app"
	@ln -s /Applications "$(DMG_STAGING)/Applications"
	@echo "==> Creating disk image $(DMG_NAME)…"
	@hdiutil create \
		-volname "$(APP_NAME)" \
		-srcfolder "$(DMG_STAGING)" \
		-ov \
		-format UDZO \
		-imagekey zlib-level=9 \
		"$(DMG_PATH)"
	@rm -rf "$(DMG_STAGING)"
	@echo "==> Disk image ready: $(DMG_PATH)"

# --- Clean -----------------------------------------------------------------
clean:
	@echo "==> Cleaning all build artifacts…"
	@rm -rf "$(BUILD_DIR)" "$(OUTPUT_DIR)"
	@echo "==> Clean complete."

clean-output:
	@rm -rf "$(OUTPUT_DIR)"
