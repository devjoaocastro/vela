APP_NAME   = Vela
BUNDLE_ID  = com.vela.app
VERSION    = 1.0.0
BUILD_DIR  = .build/arm64-apple-macosx
APP_BUNDLE = $(APP_NAME).app
DMG_NAME   = $(APP_NAME)-$(VERSION).dmg
ICON_SRC   = Sources/Vela/Resources/AppIcon.icns

# ── Build ───────────────────────────────────────────────────────────────────

.PHONY: build build-release app app-release install run run-release dmg clean

build:
	swift build 2>&1

build-release:
	swift build -c release 2>&1

# ── Assemble .app bundle ────────────────────────────────────────────────────

app: build
	@echo "→ Assembling $(APP_BUNDLE)…"
	@rm -rf $(APP_BUNDLE)
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@cp $(BUILD_DIR)/debug/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	@cp Sources/Vela/Resources/Info.plist $(APP_BUNDLE)/Contents/Info.plist
	@[ -f $(ICON_SRC) ] && cp $(ICON_SRC) $(APP_BUNDLE)/Contents/Resources/AppIcon.icns || true
	@/usr/bin/codesign --sign - --force --deep $(APP_BUNDLE) 2>/dev/null || true
	@echo "✓ $(APP_BUNDLE) ready — run: make run"

app-release: build-release
	@echo "→ Assembling $(APP_BUNDLE) (release)…"
	@rm -rf $(APP_BUNDLE)
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@cp $(BUILD_DIR)/release/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	@cp Sources/Vela/Resources/Info.plist $(APP_BUNDLE)/Contents/Info.plist
	@[ -f $(ICON_SRC) ] && cp $(ICON_SRC) $(APP_BUNDLE)/Contents/Resources/AppIcon.icns || true
	@/usr/bin/codesign --sign - --force --deep $(APP_BUNDLE) 2>/dev/null || true
	@echo "✓ $(APP_BUNDLE) (release) ready"

# ── Run ─────────────────────────────────────────────────────────────────────

run: app
	@open $(APP_BUNDLE)

run-release: app-release
	@open $(APP_BUNDLE)

# ── DMG (drag-and-drop installer) ───────────────────────────────────────────

dmg: app-release
	@echo "→ Creating $(DMG_NAME)…"
	@rm -f $(DMG_NAME)
	@mkdir -p /tmp/vela_dmg
	@cp -r $(APP_BUNDLE) /tmp/vela_dmg/
	@ln -sf /Applications /tmp/vela_dmg/Applications
	@hdiutil create -volname "Vela $(VERSION)" \
	    -srcfolder /tmp/vela_dmg \
	    -ov -format UDZO \
	    -o $(DMG_NAME) 2>&1
	@rm -rf /tmp/vela_dmg
	@echo "✓ $(DMG_NAME) ready"

# ── Install to /Applications ────────────────────────────────────────────────

install: app-release
	@echo "→ Installing to /Applications/$(APP_BUNDLE)…"
	@rm -rf /Applications/$(APP_BUNDLE)
	@cp -r $(APP_BUNDLE) /Applications/$(APP_BUNDLE)
	@echo "✓ Installed!"
	@open /Applications/$(APP_BUNDLE)

# ── Clean ───────────────────────────────────────────────────────────────────

clean:
	@rm -rf .build $(APP_BUNDLE) $(DMG_NAME) /tmp/vela_dmg
	@echo "✓ Cleaned"
