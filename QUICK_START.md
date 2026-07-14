# Device ID Spoofer - Ready to Build

## المتطلبات البسيطة

```bash
# تثبيت Xcode Command Line Tools فقط
xcode-select --install

# أو إذا كان مثبتاً بالفعل
xcode-select --reset
```

## خطوات البناء السريعة

### 1. نسخ المشروع
```bash
cd ~/dylib-device-id
```

### 2. بناء الـ dylib مباشرة
```bash
clang -shared -fPIC \
  -framework UIKit \
  -framework Foundation \
  -I. \
  -o DeviceIDSpoofer.dylib \
  Tweak.xm DeviceIDGenerator.m DeviceIDHooks.m \
  -lobjc
```

### 3. التحقق من البناء
```bash
ls -la DeviceIDSpoofer.dylib
```

## الطريقة الثانية: استخدام make البسيط

```bash
make -f Makefile.simple
```

---

## التثبيت على الجهاز

```bash
# نقل الـ dylib
scp DeviceIDSpoofer.dylib root@<device-ip>:/Library/MobileSubstrate/DynamicLibraries/

# إعادة تشغيل
ssh root@<device-ip> killall -9 SpringBoard
```

---

**هل تريد Makefile بسيط جداً؟** سأنشئه لك الآن!
