#!/bin/bash
# build.sh – Device ID Spoofer
# Builds DeviceIDSpoofer.dylib using clang + Xcode iOS SDK.
# No Theos required.
#
# Usage: ./build.sh [clean]

set -e

DYLIB="DeviceIDSpoofer.dylib"
SOURCE="Tweak.xm"

echo "🚀 Device ID Spoofer – Build Script"
echo "====================================="

# ── Clean ─────────────────────────────────────────────
if [ "$1" = "clean" ]; then
    echo "🧹 Cleaning..."
    rm -f "$DYLIB" *.o
    rm -rf packages/ obj/
    echo "✅ Clean complete"
    exit 0
fi

# ── Check for clang ───────────────────────────────────
if ! command -v clang &>/dev/null; then
    echo "❌ clang not found."
    echo "   Install Xcode and the Command Line Tools, then re-run."
    exit 1
fi

# ── Detect iOS SDK ────────────────────────────────────
SDK=$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null || true)
if [ -z "$SDK" ]; then
    echo "⚠️  iOS SDK not found via xcrun. Trying to build without -isysroot."
    SYSROOT_FLAG=""
else
    echo "✅ iOS SDK: $SDK"
    SYSROOT_FLAG="-isysroot $SDK"
fi

# ── Build ─────────────────────────────────────────────
echo "🔨 Building $DYLIB..."
clang \
    -x objective-c \
    -fPIC \
    -fno-objc-arc \
    -arch arm64 \
    -miphoneos-version-min=12.0 \
    $SYSROOT_FLAG \
    -framework UIKit \
    -framework Foundation \
    -undefined dynamic_lookup \
    -Wno-deprecated-declarations \
    -Wno-unused-variable \
    -shared \
    -o "$DYLIB" \
    "$SOURCE"

echo ""
echo "✅ Build successful!"
ls -lh "$DYLIB"
echo ""
echo "📱 Install on a jailbroken device:"
echo "   scp $DYLIB root@<device-ip>:/Library/MobileSubstrate/DynamicLibraries/"
echo "   scp DeviceIDSpoofer.plist root@<device-ip>:/Library/MobileSubstrate/DynamicLibraries/"
echo "   ssh root@<device-ip> killall -9 SpringBoard"
echo ""
echo "Or simply run:  make install DEVICE_IP=<device-ip>"
