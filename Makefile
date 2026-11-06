PROJECT := Quadra.xcodeproj
DERIVED := build
APP := $(DERIVED)/Build/Products/Debug/Quadra.app

.PHONY: generate build test run install clean

generate:
	xcodegen generate --quiet

build: generate
	xcodebuild -project $(PROJECT) -scheme Quadra -configuration Debug -derivedDataPath $(DERIVED) -quiet build

test: generate
	xcodebuild -project $(PROJECT) -scheme Quadra -derivedDataPath $(DERIVED) -destination platform=macOS,arch=arm64 -quiet test

run: build
	-pkill -x Quadra
	open $(APP)

install: generate
	xcodebuild -project $(PROJECT) -scheme Quadra -configuration Release -derivedDataPath $(DERIVED) -quiet build
	-pkill -x Quadra
	rm -rf /Applications/Quadra.app
	cp -R $(DERIVED)/Build/Products/Release/Quadra.app /Applications/
	open /Applications/Quadra.app

clean:
	rm -rf $(DERIVED) $(PROJECT)
