# Device ID Spoofer - Theos Tweak

تطبيق Theos متقدم لتغيير وتزييف معرفات الأجهزة في تطبيقات iOS.

## الميزات ✨

يقوم هذا التوك (Tweak) بتغيير جميع معرفات الأجهزة التالية:

### 1. **UDID** (Unique Device Identifier)
- معرف فريد للجهاز القديم (مستخدم في iOS 5 والإصدارات الأقدم)
- يتم توليد UDID عشوائي وحفظه بشكل دائم

### 2. **IDFA** (Identifier for Advertisers)
- معرف الإعلانات المستخدم من قبل شركات الإعلانات
- يتم توليد معرف عشوائي فريد لكل تطبيق

### 3. **IDFV** (Identifier for Vendor)
- معرف الشركة المصنعة للتطبيق
- يتم توليد معرف عشوائي فريد لكل ناشر تطبيق

### 4. **Serial Number**
- رقم تسلسلي الجهاز
- يتم توليد رقم وهمي فريد

### 5. **MAC Address**
- عنوان MAC للجهاز
- يتم توليد عنوان وهمي

### 6. **Bundle Identifier**
- معرف الحزمة للتطبيق
- يتم تسجيل الوصول فقط

## المتطلبات 📋

```bash
- Theos development environment
- iOS SDK
- MobileSubstrate
- iPhone/iPad مع iOS 12+
```

## التثبيت 🚀

### 1. استنساخ المستودع
```bash
git clone https://github.com/alaberplus2-lang/dylib-device-id.git
cd dylib-device-id
```

### 2. إعداد متغيرات البيئة
```bash
export THEOS=/opt/theos
export PATH=$THEOS/bin:$PATH
```

### 3. البناء
```bash
make package
```

### 4. التثبيت على الجهاز
```bash
make install
```

### 5. إعادة تشغيل SpringBoard
```bash
make respring
```

## البنية 🏗️

```
dylib-device-id/
├── Makefile                  # ملف البناء Theos
├── control                   # معلومات الحزمة
├── Tweak.xm                  # ملف Logos الرئيسي مع جميع الـ hooks
├── DeviceIDHooks.h          # رؤوس Hooks
├── DeviceIDHooks.m          # تنفيذ Hooks
├── DeviceIDGenerator.h      # رؤوس مولد المعرفات
├── DeviceIDGenerator.m      # تنفيذ مولد المعرفات
└── README.md                # هذا الملف
```

## التفاصيل التقنية 🔧

### آلية العمل

1. **التشغيل**: عند تحميل التوك، يتم تنفيذ دالة `%ctor` التي تعد جميع الـ hooks

2. **الـ Hooks**: يتم اعتراض استدعاءات الـ API التالية:
   - `UIDevice.uniqueIdentifier` → UDID
   - `UIDevice.identifierForVendor` → IDFV
   - `ASIdentifierManager.advertisingIdentifier` → IDFA
   - `NSBundle.bundleIdentifier` → Bundle ID

3. **التوليد**: كل معرف يتم توليده عشوائياً مرة واحدة ثم حفظه في `NSUserDefaults` للبقاء ثابتاً

4. **التسجيل**: جميع الاستدعاءات يتم تسجيلها في syslog للتحقق

### الملفات الرئيسية

#### `Tweak.xm`
ملف Logos الذي يحتوي على جميع الـ hooks باستخدام syntax Logos:
```objc
%hook ClassName
- (returnType)method {
    // Custom implementation
    return %orig;
}
%end
```

#### `DeviceIDGenerator.m`
مولد المعرفات الذي يوفر:
- توليد معرفات عشوائية
- حفظ دائم في NSUserDefaults
- دوال مساعدة للعمل مع الـ UUIDs

#### `DeviceIDHooks.m`
إعداد جميع الـ hooks باستخدام Objective-C Runtime

## الاستخدام 💻

### عرض السجلات
```bash
# من جهاز مرتبط
ssh root@<device-ip>
tail -f /var/log/syslog | grep DeviceIDSpoofer

# أو استخدام Xcode console
```

### التحقق من التوك
1. ثبت التوك
2. اذهب إلى Settings > Installed Tweaks
3. تأكد من تفعيل "Device ID Spoofer"
4. أعد تشغيل التطبيقات

### تعطيل التوك مؤقتاً
```bash
# استخدام iCleaner Pro أو:
ssh root@<device-ip>
# قم بإزالة الملف من /Library/MobileSubstrate/DynamicLibraries/
```

## المتغيرات المحفوظة 💾

يتم حفظ المعرفات الوهمية في NSUserDefaults تحت المفاتيح التالية:
- `com.deviceid.fake.udid` - UDID الوهمي
- `com.deviceid.fake.idfa` - IDFA الوهمي
- `com.deviceid.fake.idfv` - IDFV الوهمي
- `com.deviceid.fake.serial` - رقم التسلسل الوهمي
- `com.deviceid.fake.mac` - MAC Address الوهمي

## التطوير المستقبلي 🚧

- [ ] إضافة واجهة تحكم للتغيير السريع للمعرفات
- [ ] دعم تطبيقات محددة فقط (whitelist)
- [ ] توليد معرفات عشوائية جديدة بشكل دوري
- [ ] دعم macOS
- [ ] تسجيل تفصيلي أكثر
- [ ] واجهة ويب للتحكم

## الحذر والملاحظات ⚠️

1. **الخصوصية**: استخدم هذا التوك فقط للأغراض القانونية
2. **التطبيقات المصرفية**: قد لا تعمل مع تطبيقات مصرفية معينة
3. **AppStore**: قد يتم اكتشاف هذا التوك من قبل تطبيقات متقدمة
4. **النسخ الاحتياطية**: اعمل نسخة احتياطية قبل التثبيت

## استكشاف الأخطاء 🐛

### المشكلة: التوك لا يحمل
```bash
# تحقق من السجلات
ssh root@<device-ip>
tail -f /var/log/syslog

# تأكد من التثبيت
dpkg -l | grep DeviceIDSpoofer
```

### المشكلة: المعرفات لا تتغير
- تأكد من إعادة تشغيل التطبيق
- استخدم Respring بدلاً من Reboot
- تحقق من السجلات

### المشكلة: تضارب مع توكات أخرى
- عطل التوكات الأخرى ذات الصلة
- استخدم iCleaner Pro لتنظيف الآثار

## الترخيص 📝

MIT License - انظر LICENSE للتفاصيل

## المساهمة 🤝

الاقتراحات والتحسينات مرحب بها!

```bash
git checkout -b feature/your-feature
git commit -am 'Add your feature'
git push origin feature/your-feature
```

## الدعم والمساعدة 📧

للأسئلة والمساعدة:
- فتح issue في GitHub
- مراسلة بريد إلكتروني

---

**تم تطويره بواسطة**: alaberplus2-lang  
**آخر تحديث**: 2026-07-14  
**الإصدار**: 1.0.0
