CONFIG ?= release
BUILD_DIR := .build/$(CONFIG)
APP := dist/Rocky.app

.PHONY: build test app run clean

build:
	swift build -c $(CONFIG)

test:
	swift test

app: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp Support/Info.plist $(APP)/Contents/Info.plist
	printf 'APPL????' > $(APP)/Contents/PkgInfo
	cp $(BUILD_DIR)/Rocky $(APP)/Contents/MacOS/Rocky
	cp $(BUILD_DIR)/vibenotch-hook $(APP)/Contents/MacOS/vibenotch-hook
	mkdir -p $(APP)/Contents/Resources/Sounds $(APP)/Contents/Resources/Art $(APP)/Contents/Resources/Fonts
	cp Support/Sounds/*.mp3 $(APP)/Contents/Resources/Sounds/
	cp Support/Art/rocky/*.png $(APP)/Contents/Resources/Art/
	cp Support/Art/rocky-idle/*.png $(APP)/Contents/Resources/Art/
	cp Support/Fonts/PressStart2P-Regular.ttf Support/Fonts/OFL.txt $(APP)/Contents/Resources/Fonts/
	if [ -f Support/AppIcon.icns ]; then cp Support/AppIcon.icns $(APP)/Contents/Resources/AppIcon.icns; fi
	codesign --force --deep --sign - $(APP)

run: app
	open $(APP)

clean:
	rm -rf .build dist
