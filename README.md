# Device ID Spoofer – dylib

مكتبة **dylib** خفيفة بالكامل بـ Objective-C تضخّ نفسها في أي تطبيق iOS لتعديل وتزييف معرّفات الجهاز، مع لوحة تحكم عائمة أنيقة.

## الميزات ✨

| الميزة | التفاصيل |
|--------|---------|
| زر عائم ⚙️ | يظهر تلقائياً في كل تطبيق مُضاف إليه الـ dylib |
| **نقرة** أو **ضغطة مطوّلة** | كلاهما يفتح لوحة التحكم |
| سحب الزر | يمكن تحريك الزر لأي مكان على الشاشة |
| تعديل **UDID** | معرّف الجهاز الفريد |
| تعديل **IDFA** | معرّف الإعلانات |
| تعديل **IDFV** | معرّف المطوّر |
| توليد عشوائي | معرّفات UUID جديدة بنقرة واحدة |
| إعادة تعيين | حذف جميع المعرّفات المخصّصة |
| تفعيل / تعطيل | مفتاح للتحكم بالـ Tweak بالكامل |
| تخزين دائم | القيم محفوظة في NSUserDefaults |
| iOS 12+ / arm64 | لا يتطلب Theos أو Substrate للبناء |

## البنية 🏗️

```
dylib-device-id/
├── Tweak.xm                    ← الكود الرئيسي (Pure Objective-C)
├── Makefile                    ← بناء بدون Theos
├── build.sh                    ← سكريبت بناء سريع
├── control                     ← معلومات الحزمة
├── DeviceIDSpoofer.plist       ← فلتر Substrate (لكل التطبيقات)
├── layout/
│   ├── DEBIAN/
│   │   ├── control
│   │   └── postinst
│   └── Library/MobileSubstrate/DynamicLibraries/
│       └── DeviceIDSpoofer.plist
├── DeviceIDGenerator.h / .m    ← مولّد المعرّفات
└── DeviceIDHooks.h / .m        ← مساعد الـ Hooks
```

## المتطلبات 📋

- macOS مع **Xcode** و **Command Line Tools**
- لا يلزم تثبيت Theos أو Substrate

```bash
xcode-select --install   # إذا لم تكن مثبّتة
```

## البناء 🔨

```bash
git clone https://github.com/alaberplus2-lang/dylib-device-id.git
cd dylib-device-id

# الطريقة 1 – Makefile
make

# الطريقة 2 – سكريبت
./build.sh

# تنظيف
make clean
```

النتيجة: `DeviceIDSpoofer.dylib`

## التثبيت على جهاز مجلبر 📱

```bash
# عبر make مباشرة
make install DEVICE_IP=192.168.1.100

# أو يدوياً
scp DeviceIDSpoofer.dylib root@192.168.1.100:/Library/MobileSubstrate/DynamicLibraries/
scp DeviceIDSpoofer.plist root@192.168.1.100:/Library/MobileSubstrate/DynamicLibraries/
ssh root@192.168.1.100 killall -9 SpringBoard
```

## دمج الـ dylib مع تطبيق (بدون جلبريك) 💉

### باستخدام `insert_dylib`:
```bash
# ثبّت insert_dylib من: https://github.com/Tyilo/insert_dylib
insert_dylib @executable_path/DeviceIDSpoofer.dylib YourApp.app/YourApp --strip-codesig

# نسخ الـ dylib
cp DeviceIDSpoofer.dylib YourApp.app/

# إعادة التوقيع وإعادة الحزم
codesign -fs - --deep YourApp.app
```

### باستخدام `optool`:
```bash
optool install -c load -p @executable_path/DeviceIDSpoofer.dylib -t YourApp.app/YourApp
```

## الاستخدام داخل التطبيق 🎛️

بعد إضافة الـ dylib:

1. افتح التطبيق
2. ابحث عن الزر الأخضر ⚙️ في الزاوية السفلية اليمنى
3. اضغط عليه أو اضغط مطوّلاً لفتح لوحة التحكم
4. من لوحة التحكم يمكنك:
   - مشاهدة الحالة الحالية
   - تعديل UDID / IDFA / IDFV يدوياً
   - توليد معرّفات عشوائية
   - إعادة تعيين الكل
   - تفعيل أو تعطيل الـ Tweak

## متغيرات NSUserDefaults 💾

| المفتاح | الوصف |
|---------|-------|
| `com.deviceid.custom.udid` | UDID المخصّص |
| `com.deviceid.custom.idfa` | IDFA المخصّص |
| `com.deviceid.custom.idfv` | IDFV المخصّص |
| `com.deviceid.enabled`     | حالة التفعيل |

## آلية العمل 🔧

```
__attribute__((constructor))
    ├── LoadSettings()     ← تحميل القيم المحفوظة
    ├── InstallHooks()     ← method_setImplementation لـ UIDevice + ASIdentifierManager
    └── dispatch_after()   ← إضافة الزر العائم بعد تشغيل التطبيق
```

لا يتطلب `%hook` / `%orig` – يعمل بمجرد تحميل المكتبة في أي عملية.

## ملاحظات ⚠️

- استخدم هذه الأداة للأغراض القانونية فقط (الاختبار والتطوير والخصوصية)
- بعض التطبيقات قد تكتشف التعديل

## الترخيص 📝

MIT License

---

**المطوّر**: alaberplus2-lang  
**الإصدار**: 1.0.0  
**التاريخ**: 2026-07-14
