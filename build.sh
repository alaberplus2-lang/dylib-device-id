#!/bin/bash
# Build script for Device ID Spoofer
# لا يتطلب Theos - يعمل مع Xcode tools فقط

echo "🚀 Device ID Spoofer - Build Script"
echo "===================================="

# التحقق من Xcode
if ! command -v clang &> /dev/null; then
    echo "❌ clang not found. Installing Xcode Command Line Tools..."
    xcode-select --install
    exit 1
fi

echo "✅ Xcode tools found"

# البناء
echo "🔨 Building Device ID Spoofer..."
clang -fPIC -fno-objc-arc \
    -shared \
    -undefined dynamic_lookup \
    -framework UIKit \
    -framework Foundation \
    -framework CoreTelephony \
    -o DeviceIDSpoofer.dylib \
    Tweak.xm DeviceIDGenerator.m DeviceIDHooks.m

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    ls -lh DeviceIDSpoofer.dylib
    
    echo ""
    echo "📱 Installation:"
    echo "  scp DeviceIDSpoofer.dylib root@<device-ip>:/Library/MobileSubstrate/DynamicLibraries/"
    echo "  ssh root@<device-ip> killall -9 SpringBoard"
else
    echo "❌ Build failed!"
    exit 1
fi
