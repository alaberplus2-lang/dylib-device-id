export THEOS=/opt/theos
export THEOS_MAKE_PATH = $(THEOS)/makefiles
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DeviceIDSpoofer
DeviceIDSpoofer_FILES = Tweak.xm SettingsButton.xm DeviceIDHooks.m DeviceIDGenerator.m
DeviceIDSpoofer_FRAMEWORKS = Foundation UIKit
DeviceIDSpoofer_PRIVATE_FRAMEWORKS = CoreTelephony
DeviceIDSpoofer_CFLAGS = -fno-objc-arc -Wno-error=unused-variable

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"

after-package::
	@echo "✅ Package built successfully!"
	@echo "📦 Location: packages/"
	@echo "📱 To install: make install"
