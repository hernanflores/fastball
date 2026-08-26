# FastBall — native macOS build.
#
# Uses swiftc directly so it builds with the Command Line Tools alone (no Xcode
# required). The sources are laid out so an .xcodeproj can be dropped on top later.

APP_NAME    := FastBall
BUNDLE      := build/$(APP_NAME).app
CONTENTS    := $(BUNDLE)/Contents
BINARY      := $(CONTENTS)/MacOS/$(APP_NAME)
SOURCES     := $(shell find FastBall -name '*.swift')
ICONSET     := $(wildcard assets/AppIcon.iconset/*)
RESOURCES   := $(wildcard FastBall/Resources/*)
SDK         := $(shell xcrun --show-sdk-path --sdk macosx)
SWIFTFLAGS  := -sdk $(SDK) -O -swift-version 5

.PHONY: all run test clean dmg sign

all: $(BINARY)

$(BINARY): $(SOURCES) Resources-Info.plist entitlements.plist $(ICONSET) $(RESOURCES)
	@mkdir -p $(CONTENTS)/MacOS $(CONTENTS)/Resources build/tmp
	swiftc $(SWIFTFLAGS) -target arm64-apple-macos14.0 -o build/tmp/$(APP_NAME)-arm64 $(SOURCES)
	swiftc $(SWIFTFLAGS) -target x86_64-apple-macos14.0 -o build/tmp/$(APP_NAME)-x86_64 $(SOURCES)
	lipo -create -output $@ build/tmp/$(APP_NAME)-arm64 build/tmp/$(APP_NAME)-x86_64
	@rm -rf build/tmp
	@cp Resources-Info.plist $(CONTENTS)/Info.plist
	@iconutil -c icns assets/AppIcon.iconset -o $(CONTENTS)/Resources/AppIcon.icns
	@cp FastBall/Resources/MenuBarIcon.png FastBall/Resources/MenuBarIcon@2x.png $(CONTENTS)/Resources/
	@printf 'APPL????' > $(CONTENTS)/PkgInfo
	@$(MAKE) --no-print-directory sign
	@echo "built $(BUNDLE)"

# Ad-hoc signature. A stable identity matters here: the global hotkey and the
# login item are both remembered per-signature, so an unsigned rebuild would
# look like a different app to macOS every time.
sign:
	@codesign --force --deep --sign - --entitlements entitlements.plist $(BUNDLE)

run: all
	@pkill -x $(APP_NAME) || true
	@open $(BUNDLE)

# Synthesized-NSEvent smoke test over the keyboard routing.
test: all
	@pkill -x $(APP_NAME) || true
	@rm -f /tmp/fastball-selftest.txt
	@open $(BUNDLE) --args --selftest
	@sleep 5
	@cat /tmp/fastball-selftest.txt
	@grep -q "ALL PASSED" /tmp/fastball-selftest.txt

dmg: all
	@rm -f build/$(APP_NAME).dmg
	@hdiutil create -volname $(APP_NAME) -srcfolder $(BUNDLE) -ov -format UDZO build/$(APP_NAME).dmg
	@echo "built build/$(APP_NAME).dmg"

clean:
	rm -rf build
