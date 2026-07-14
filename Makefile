# Device ID Spoofer – Makefile
# Builds DeviceIDSpoofer.dylib with standard clang + Xcode SDK.
# No Theos / Substrate installation required.
#
# Usage:
#   make                              → build dylib
#   make clean                        → remove build artefacts
#   make package                      → copy dylib to packages/
#   make install DEVICE_IP=<ip>       → copy dylib + plist to jailbroken device
#
# Requires: Xcode + Command Line Tools (macOS)

DYLIB   := DeviceIDSpoofer.dylib
PLIST   := DeviceIDSpoofer.plist
SOURCES := Tweak.xm
CC      := clang

# Auto-detect the iOS SDK via xcrun; falls back gracefully if Xcode is absent
SDK     := $(shell xcrun --sdk iphoneos --show-sdk-path 2>/dev/null)

CFLAGS  := -x objective-c \
            -fPIC \
            -fno-objc-arc \
            -arch arm64 \
            -miphoneos-version-min=12.0 \
            -framework UIKit \
            -framework Foundation \
            -undefined dynamic_lookup \
            -Wno-deprecated-declarations \
            -Wno-unused-variable

ifneq ($(SDK),)
CFLAGS  += -isysroot $(SDK)
endif

.PHONY: all clean package install help

all: $(DYLIB)

$(DYLIB): $(SOURCES)
	@echo "🔨 Building $(DYLIB)..."
	$(CC) $(CFLAGS) -shared -o $@ $^
	@echo "✅ Build successful!"
	@ls -lh $@

clean:
	@echo "🧹 Cleaning..."
	@rm -f $(DYLIB) *.o
	@rm -rf packages/ obj/ .theos/
	@echo "✅ Done"

package: $(DYLIB)
	@echo "📦 Creating package..."
	@mkdir -p packages
	@cp $(DYLIB) packages/
	@echo "✅ Package ready: packages/$(DYLIB)"

install: $(DYLIB)
	@[ -n "$(DEVICE_IP)" ] || \
		(echo "❌  Usage: make install DEVICE_IP=192.168.1.100" && exit 1)
	@echo "📱 Installing on $(DEVICE_IP)..."
	scp $(DYLIB) root@$(DEVICE_IP):/Library/MobileSubstrate/DynamicLibraries/
	@if [ -f "$(PLIST)" ]; then \
		scp $(PLIST) root@$(DEVICE_IP):/Library/MobileSubstrate/DynamicLibraries/; \
	fi
	ssh root@$(DEVICE_IP) "killall -9 SpringBoard || true"
	@echo "✅ Installed successfully!"

help:
	@echo "Targets:"
	@echo "  make                               Build dylib"
	@echo "  make clean                         Remove build artefacts"
	@echo "  make package                       Copy dylib to packages/"
	@echo "  make install DEVICE_IP=x.x.x.x    Install on jailbroken device"
