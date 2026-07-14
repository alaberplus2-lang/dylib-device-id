/*
 * DeviceIDSpoofer – Tweak.xm
 *
 * Pure Objective-C implementation. No Substrate / Logos preprocessor needed.
 * Compile with clang as Objective-C (-x objective-c) and link as a shared
 * library (-shared). The dylib self-installs its hooks and UI via
 * __attribute__((constructor)).
 *
 * Features:
 *   • Floating ⚙️ button added to every app's key window
 *   • Opens the control panel on tap OR long-press (0.5 s)
 *   • Drag the button anywhere on screen
 *   • 3-section table: status / custom IDs / quick actions
 *   • Hooks: UDID  ·  IDFV  ·  IDFA
 *   • Persistent storage via NSUserDefaults
 *   • iOS 12 +  |  arm64
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <Security/Security.h>

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Constants & State
// ─────────────────────────────────────────────────────────────────────────────

static NSString * const kUDIDKey      = @"com.deviceid.custom.udid";
static NSString * const kIDFAKey      = @"com.deviceid.custom.idfa";
static NSString * const kIDFVKey      = @"com.deviceid.custom.idfv";
static NSString * const kDeviceIDKey  = @"com.deviceid.custom.deviceid";
static NSString * const kEnabledKey   = @"com.deviceid.enabled";

static NSString *sCustomUDID     = nil;
static NSString *sCustomIDFA     = nil;
static NSString *sCustomIDFV     = nil;
static NSString *sCustomDeviceID = nil;
static BOOL      sTweakEnabled   = YES;
static BOOL      sButtonAdded  = NO;   // global guard – prevents double-add

static NSUInteger const kMaxDisplayLength = 28; // chars shown in the ID subtitle

static void InstallUserDefaultsHooks(void);

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Shared plist storage
// Stored at the standard jailbreak prefs path so every injected process reads
// the same file, regardless of which app the user last configured the tweak in.
// ─────────────────────────────────────────────────────────────────────────────

static NSString * const kPrefsFilePath =
    @"/var/mobile/Library/Preferences/com.deviceid.spoofer.plist";

/// Returns the app-container fallback path (always writable within the sandbox).
static NSString *FallbackPrefsPath(void) {
    return [NSHomeDirectory() stringByAppendingPathComponent:
            @"Library/Preferences/com.deviceid.spoofer.plist"];
}

/// Returns a mutable snapshot of the on-disk prefs, or an empty dict.
/// Tries the shared jailbreak path first; falls back to the app container.
static NSMutableDictionary *ReadPrefs(void) {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:kPrefsFilePath];
    if (!d) {
        d = [NSDictionary dictionaryWithContentsOfFile:FallbackPrefsPath()];
    }
    return d ? [d mutableCopy] : [NSMutableDictionary dictionary];
}

/// Atomically writes the prefs dict to disk.
/// Tries the shared jailbreak path first; if that fails, writes to the app container.
static void WritePrefs(NSMutableDictionary *d) {
    if ([d writeToFile:kPrefsFilePath atomically:YES]) return;

    // Shared path not writable (sandboxed app without Substrate) – use container.
    NSString *fallback = FallbackPrefsPath();
    NSString *dir = [fallback stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    if (![d writeToFile:fallback atomically:YES]) {
        NSLog(@"[DeviceIDSpoofer] ❌ WritePrefs: كلا المسارين فشلا – لن تُحفظ الإعدادات");
    } else {
        NSLog(@"[DeviceIDSpoofer] ⚠️ WritePrefs: استُخدم مسار حاوية التطبيق (المسار المشترك محمي)");
    }
}

static void LoadSettings(void) {
    NSDictionary *d = ReadPrefs();
    sCustomUDID     = d[kUDIDKey];
    sCustomIDFA     = d[kIDFAKey];
    sCustomIDFV     = d[kIDFVKey];
    sCustomDeviceID = d[kDeviceIDKey];
    // If the key was never written, default to enabled (true).
    id en = d[kEnabledKey];
    sTweakEnabled = en ? [en boolValue] : YES;
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Settings View Controller
// ─────────────────────────────────────────────────────────────────────────────

@interface DeviceIDSettingsViewController : UITableViewController
+ (instancetype)sharedInstance;
- (void)addFloatingButton;
- (void)openPanel;
@end

@implementation DeviceIDSettingsViewController

+ (instancetype)sharedInstance {
    static DeviceIDSettingsViewController *s;
    static dispatch_once_t tok;
    dispatch_once(&tok, ^{
        s = [[DeviceIDSettingsViewController alloc] initWithStyle:UITableViewStyleGrouped];
    });
    return s;
}

- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self) self.title = @"🎛️ Device ID Spoofer";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self
                                                      action:@selector(closePanel)];
    LoadSettings();
}

- (void)closePanel {
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

// ── Window helper ─────────────────────────────────────────────────────────────

- (UIWindow *)activeKeyWindow {
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)scene;
            if (ws.activationState != UISceneActivationStateForegroundActive) continue;
            for (UIWindow *w in ws.windows) {
                if (w.isKeyWindow) return w;
            }
        }
    }
    return [UIApplication sharedApplication].keyWindow;
}

// ── Floating Button ───────────────────────────────────────────────────────────

- (void)addFloatingButton {
    // Global guard: only ever add the button once across all dispatch callbacks
    if (sButtonAdded) return;

    UIWindow *win = [self activeKeyWindow];
    if (!win) return;

    // Per-window guard (defensive): don't add a second button to the same window
    for (UIView *v in win.subviews) {
        if (v.tag == 0xDEC0DE) return;
    }
    sButtonAdded = YES;

    CGFloat side = 60.0f;
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.tag   = 0xDEC0DE;
    btn.frame = CGRectMake(win.bounds.size.width - side - 12,
                           win.bounds.size.height - side - 100,
                           side, side);

    btn.backgroundColor     = [UIColor colorWithRed:0.18f green:0.78f blue:0.35f alpha:0.95f];
    btn.layer.cornerRadius  = side / 2.0f;
    btn.clipsToBounds       = NO;
    btn.layer.shadowColor   = [UIColor blackColor].CGColor;
    btn.layer.shadowOpacity = 0.35f;
    btn.layer.shadowRadius  = 7.0f;
    btn.layer.shadowOffset  = CGSizeMake(0, 3);

    [btn setTitle:@"⚙️" forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:28];

    // Tap → open panel
    [btn addTarget:self
            action:@selector(openPanel)
  forControlEvents:UIControlEventTouchUpInside];

    // Long press → open panel
    UILongPressGestureRecognizer *lp =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                      action:@selector(handleLongPress:)];
    lp.minimumPressDuration = 0.5;
    [btn addGestureRecognizer:lp];

    // Pan → drag button
    UIPanGestureRecognizer *pan =
        [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                action:@selector(handlePan:)];
    pan.maximumNumberOfTouches = 1;
    [btn addGestureRecognizer:pan];

    [win addSubview:btn];
    NSLog(@"[DeviceIDSpoofer] Floating button added ✓");
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gr {
    if (gr.state == UIGestureRecognizerStateBegan) [self openPanel];
}

- (void)handlePan:(UIPanGestureRecognizer *)gr {
    UIView *v = gr.view;
    CGPoint d = [gr translationInView:v.superview];
    v.center  = CGPointMake(v.center.x + d.x, v.center.y + d.y);
    [gr setTranslation:CGPointZero inView:v.superview];
}

- (void)openPanel {
    LoadSettings();
    [self.tableView reloadData];

    UIWindow *win  = [self activeKeyWindow];
    UIViewController *root = win.rootViewController;
    while (root.presentedViewController) root = root.presentedViewController;

    // Avoid double-presenting
    if ([root isKindOfClass:[UINavigationController class]] &&
        ((UINavigationController *)root).topViewController == self) return;

    UINavigationController *nav =
        [[UINavigationController alloc] initWithRootViewController:self];
    if (@available(iOS 13.0, *)) {
        nav.modalPresentationStyle = UIModalPresentationAutomatic;
    }
    [root presentViewController:nav animated:YES completion:nil];
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Table View Data Source
// ─────────────────────────────────────────────────────────────────────────────

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 3; }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    if (s == 0) return 2;   // Status row + toggle
    if (s == 1) return 4;   // UDID · IDFA · IDFV · Device ID hash
    return 2;               // Generate random · Reset all
}

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s {
    if (s == 0) return @"📱 الحالة الحالية";
    if (s == 1) return @"🔧 تخصيص المعرفات";
    return @"⚡ إجراءات سريعة";
}

- (UITableViewCell *)tableView:(UITableView *)tv
         cellForRowAtIndexPath:(NSIndexPath *)ip {

    NSString *rid = [NSString stringWithFormat:@"DID_%ld_%ld",
                     (long)ip.section, (long)ip.row];
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:rid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:rid];
    }
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;

    if (ip.section == 0) {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        if (ip.row == 0) {
            cell.textLabel.text        = @"حالة الـ Tweak";
            cell.detailTextLabel.text  = sTweakEnabled ? @"✅ مفعّل" : @"❌ معطّل";
        } else {
            cell.textLabel.text = @"تفعيل / تعطيل";
            UISwitch *sw = [[UISwitch alloc] init];
            sw.on = sTweakEnabled;
            [sw addTarget:self
                   action:@selector(toggleEnabled:)
         forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
        }

    } else if (ip.section == 1) {
        NSArray *titles = @[@"UDID", @"IDFA", @"IDFV", @"معرف الجهاز"];
        NSArray *keys   = @[kUDIDKey, kIDFAKey, kIDFVKey, kDeviceIDKey];
        NSString *val = ReadPrefs()[keys[ip.row]];

        cell.textLabel.text = titles[ip.row];
        if (val.length > 0) {
            NSUInteger maxLen = MIN(kMaxDisplayLength, val.length);
            cell.detailTextLabel.text  = [val substringToIndex:maxLen];
            cell.detailTextLabel.textColor = [UIColor systemBlueColor];
        } else {
            cell.detailTextLabel.text  = @"(الافتراضي – لم يُعيَّن)";
            cell.detailTextLabel.textColor = [UIColor systemGrayColor];
        }
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    } else {
        NSArray *actions = @[@"🔀 توليد معرفات عشوائية", @"🔄 إعادة تعيين الكل"];
        cell.textLabel.text = actions[ip.row];
        cell.accessoryType  = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section == 1) {
        [self editIDAtIndex:ip.row];
    } else if (ip.section == 2) {
        if (ip.row == 0) [self generateRandomIDs];
        else             [self resetAllIDs];
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Shows an alert telling the user to restart the app so the hook takes effect
/// on already-cached identifiers.
- (void)showRestartRequiredWithTitle:(NSString *)title message:(NSString *)msg {
    UIAlertController *a = [UIAlertController
        alertControllerWithTitle:title
                         message:[NSString stringWithFormat:
                                  @"%@\n\n⚠️ أغلق التطبيق تماماً وأعد فتحه حتى تنعكس التغييرات.",
                                  msg]
                  preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"حسناً"
                                          style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction *_) {
        [self.tableView reloadData];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

/// Returns YES if the string is a valid UUID (with or without dashes).
static BOOL isValidUUID(NSString *s) {
    if (!s || s.length == 0) return NO;
    // Accepts the standard 8-4-4-4-12 form that NSUUID expects
    return [[NSUUID alloc] initWithUUIDString:s] != nil;
}

/// Returns YES if every character is a lowercase or uppercase hex digit.
static BOOL isHexChar(unichar c) {
    return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
}

/// Returns a random 64-character lowercase hex string (256-bit random value).
static NSString *randomHex64(void) {
    uint8_t bytes[32];
    arc4random_buf(bytes, sizeof(bytes));
    NSMutableString *hex = [NSMutableString stringWithCapacity:64];
    for (int i = 0; i < 32; i++) {
        [hex appendFormat:@"%02x", bytes[i]];
    }
    return [NSString stringWithString:hex];
}

/// Returns YES if s is exactly 64 hex characters (SHA-256 hex digest format).
static BOOL isHex64(NSString *s) {
    if (!s || s.length != 64) return NO;
    for (NSUInteger i = 0; i < 64; i++) {
        if (!isHexChar([s characterAtIndex:i])) return NO;
    }
    return YES;
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Actions
// ─────────────────────────────────────────────────────────────────────────────

- (void)toggleEnabled:(UISwitch *)sw {
    sTweakEnabled = sw.on;
    NSMutableDictionary *d = ReadPrefs();
    d[kEnabledKey] = @(sTweakEnabled);
    WritePrefs(d);
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0]
                  withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)editIDAtIndex:(NSInteger)idx {
    NSArray *titles = @[@"UDID", @"IDFA", @"IDFV", @"معرف الجهاز"];
    NSArray *keys   = @[kUDIDKey, kIDFAKey, kIDFVKey, kDeviceIDKey];
    NSArray *hints  = @[
        @"مثال: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
        @"مثال: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
        @"مثال: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
        @"مثال: f8545d35b7959dc75183e8fcfc916154235f7d9f9b27feed76d962c0021d68ea"
    ];
    NSString *key = keys[idx];

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:[NSString stringWithFormat:@"تعديل %@", titles[idx]]
                         message:@"أدخل القيمة الجديدة (اتركه فارغاً للحذف)"
                  preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder              = hints[idx];
        tf.text                     = ReadPrefs()[key] ?: @"";
        tf.autocorrectionType       = UITextAutocorrectionTypeNo;
        tf.autocapitalizationType   = UITextAutocapitalizationTypeNone;
    }];

    [alert addAction:[UIAlertAction
        actionWithTitle:@"حفظ"
                  style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *a) {
        NSString *v = [alert.textFields.firstObject.text
                       stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

        // معرف الجهاز (idx=3) must be exactly 64 hex characters.
        if (v.length > 0 && idx == 3 && !isHex64(v)) {
            UIAlertController *err = [UIAlertController
                alertControllerWithTitle:@"❌ صيغة غير صحيحة"
                                 message:@"يجب أن يكون المعرف 64 حرفاً سداسي عشري (SHA-256)\nمثال: f8545d35b795..."
                          preferredStyle:UIAlertControllerStyleAlert];
            [err addAction:[UIAlertAction actionWithTitle:@"حسناً"
                                                    style:UIAlertActionStyleDefault
                                                  handler:nil]];
            [self presentViewController:err animated:YES completion:nil];
            return;
        }

        // IDFA (idx=1) and IDFV (idx=2) must be valid UUIDs so the hook
        // can reconstruct them via -[NSUUID initWithUUIDString:].
        if (v.length > 0 && (idx == 1 || idx == 2) && !isValidUUID(v)) {
            UIAlertController *err = [UIAlertController
                alertControllerWithTitle:@"❌ صيغة غير صحيحة"
                                 message:@"يجب أن تكون القيمة UUID صحيحة\nمثال: 550e8400-e29b-41d4-a716-446655440000"
                          preferredStyle:UIAlertControllerStyleAlert];
            [err addAction:[UIAlertAction actionWithTitle:@"حسناً"
                                                   style:UIAlertActionStyleDefault
                                                  handler:nil]];
            [self presentViewController:err animated:YES completion:nil];
            return;
        }

        NSMutableDictionary *d = ReadPrefs();
        if (v.length > 0) d[key] = v;
        else              [d removeObjectForKey:key];
        WritePrefs(d);
        LoadSettings();
        [self.tableView reloadData];
        [self showRestartRequiredWithTitle:@"✅ تم الحفظ"
                                  message:[NSString stringWithFormat:@"تم حفظ %@.", titles[idx]]];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)generateRandomIDs {
    NSMutableDictionary *d = ReadPrefs();
    d[kUDIDKey]     = [NSUUID UUID].UUIDString;
    d[kIDFAKey]     = [NSUUID UUID].UUIDString;
    d[kIDFVKey]     = [NSUUID UUID].UUIDString;
    d[kDeviceIDKey] = randomHex64();
    WritePrefs(d);
    LoadSettings();
    [self.tableView reloadData];
    [self showRestartRequiredWithTitle:@"✅ تم التوليد"
                               message:@"تم توليد معرفات عشوائية جديدة بنجاح."];
}

- (void)resetAllIDs {
    UIAlertController *confirm = [UIAlertController
        alertControllerWithTitle:@"إعادة تعيين الكل"
                         message:@"هل تريد حذف جميع المعرفات المخصصة؟"
                  preferredStyle:UIAlertControllerStyleAlert];

    [confirm addAction:[UIAlertAction
        actionWithTitle:@"نعم، إعادة تعيين"
                  style:UIAlertActionStyleDestructive
                handler:^(UIAlertAction *a) {
        NSMutableDictionary *d = ReadPrefs();
        [d removeObjectForKey:kUDIDKey];
        [d removeObjectForKey:kIDFAKey];
        [d removeObjectForKey:kIDFVKey];
        [d removeObjectForKey:kDeviceIDKey];
        WritePrefs(d);
        LoadSettings();
        [self.tableView reloadData];
    }]];

    [confirm addAction:[UIAlertAction actionWithTitle:@"إلغاء"
                                                style:UIAlertActionStyleCancel
                                              handler:nil]];
    [self presentViewController:confirm animated:YES completion:nil];
}

@end

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Method-swizzling hooks (no Substrate required)
// ─────────────────────────────────────────────────────────────────────────────

typedef NSString *(*UniqueIdentifierIMP)(id, SEL);
typedef NSUUID   *(*IdentifierForVendorIMP)(id, SEL);
typedef NSUUID   *(*AdvertisingIdentifierIMP)(id, SEL);

static UniqueIdentifierIMP    sOrigUniqueIdentifier    = NULL;
static IdentifierForVendorIMP sOrigIdentifierForVendor = NULL;
static AdvertisingIdentifierIMP sOrigAdvertisingId     = NULL;

static NSString *Hooked_uniqueIdentifier(id self, SEL _cmd) {
    if (!sTweakEnabled || !sCustomUDID) return sOrigUniqueIdentifier(self, _cmd);
    return sCustomUDID;
}

static NSUUID *Hooked_identifierForVendor(id self, SEL _cmd) {
    if (!sTweakEnabled || !sCustomIDFV) return sOrigIdentifierForVendor(self, _cmd);
    return [[NSUUID alloc] initWithUUIDString:sCustomIDFV];
}

static NSUUID *Hooked_advertisingIdentifier(id self, SEL _cmd) {
    if (!sTweakEnabled || !sCustomIDFA) return sOrigAdvertisingId(self, _cmd);
    return [[NSUUID alloc] initWithUUIDString:sCustomIDFA];
}

static void InstallHooks(void) {
    // UIDevice – uniqueIdentifier (deprecated but still used)
    Class uiDeviceClass = [UIDevice class];

    SEL udidSel = NSSelectorFromString(@"uniqueIdentifier");
    Method udidM = class_getInstanceMethod(uiDeviceClass, udidSel);
    if (udidM) {
        sOrigUniqueIdentifier =
            (UniqueIdentifierIMP)method_getImplementation(udidM);
        method_setImplementation(udidM, (IMP)Hooked_uniqueIdentifier);
    } else {
        NSLog(@"[DeviceIDSpoofer] uniqueIdentifier not found (expected on modern iOS)");
    }

    // UIDevice – identifierForVendor (IDFV)
    SEL idfvSel = @selector(identifierForVendor);
    Method idfvM = class_getInstanceMethod(uiDeviceClass, idfvSel);
    if (idfvM) {
        sOrigIdentifierForVendor =
            (IdentifierForVendorIMP)method_getImplementation(idfvM);
        method_setImplementation(idfvM, (IMP)Hooked_identifierForVendor);
    } else {
        NSLog(@"[DeviceIDSpoofer] identifierForVendor hook failed: selector not found");
    }

    // ASIdentifierManager – advertisingIdentifier (IDFA)
    // Use NSClassFromString to avoid requiring AdSupport at link time
    void *adSupportHandle =
        dlopen("/System/Library/Frameworks/AdSupport.framework/AdSupport", RTLD_LAZY);
    if (!adSupportHandle) {
        const char *err = dlerror();
        NSLog(@"[DeviceIDSpoofer] Failed to load AdSupport: %s", err ? err : "unknown error");
    }
    Class asmClass = NSClassFromString(@"ASIdentifierManager");
    if (asmClass) {
        SEL idfaSel = NSSelectorFromString(@"advertisingIdentifier");
        Method idfaM = class_getInstanceMethod(asmClass, idfaSel);
        if (idfaM) {
            sOrigAdvertisingId =
                (AdvertisingIdentifierIMP)method_getImplementation(idfaM);
            method_setImplementation(idfaM, (IMP)Hooked_advertisingIdentifier);
        } else {
            NSLog(@"[DeviceIDSpoofer] advertisingIdentifier hook failed: selector not found");
        }
    } else {
        NSLog(@"[DeviceIDSpoofer] ASIdentifierManager class not loaded");
    }

    NSLog(@"[DeviceIDSpoofer] Hooks installed ✓");
    InstallUserDefaultsHooks();
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Keychain interpose – SecItemCopyMatching
// Intercepts keychain reads that return a 64-char hex device-ID fingerprint
// (common pattern in apps that store a SHA-256 device hash in the keychain)
// and replaces the value with the user-configured custom device ID.
// DYLD_INTERPOSE patches the GOT of every image in the process, so the hook
// fires for both the target app and any frameworks it links.
//
// Ownership note: SecItemCopyMatching returns a +1 retained CF object when
// errSecSuccess. All Security framework return types are toll-free bridged
// with their Foundation counterparts, so CFRelease plus normal retain/copy
// ownership conventions work identically for pure CF and bridged NS objects.
// ─────────────────────────────────────────────────────────────────────────────

#define DYLD_INTERPOSE(_replacement, _replacee) \
    __attribute__((used)) static struct { \
        const void *replacement; \
        const void *replacee; \
    } _interpose_##_replacee \
    __attribute__((section("__DATA,__interpose"))) = { \
        (const void *)(unsigned long)&_replacement, \
        (const void *)(unsigned long)&_replacee \
    };

static OSStatus my_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
    OSStatus status = SecItemCopyMatching(query, result);
    if (!sTweakEnabled || !sCustomDeviceID || sCustomDeviceID.length == 0)
        return status;
    if (status != errSecSuccess || !result || !*result)
        return status;

    CFTypeID resultType = CFGetTypeID(*result);

    // Result is a CFString (kSecReturnData=NO, kSecReturnRef=YES, etc.)
    if (resultType == CFStringGetTypeID()) {
        NSString *s = (__bridge NSString *)(*result);
        if (isHex64(s)) {
            CFRelease(*result);
            *result = (CFTypeRef)[sCustomDeviceID copy];
        }
        return status;
    }

    // Result is a CFData – decode as UTF-8 and check
    if (resultType == CFDataGetTypeID()) {
        NSData *d = (__bridge NSData *)(*result);
        NSString *s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
        if (isHex64(s)) {
            NSData *newData = [sCustomDeviceID dataUsingEncoding:NSUTF8StringEncoding];
            CFRelease(*result);
            *result = (CFTypeRef)[newData retain];
        }
        return status;
    }

    // Result is an array of dicts (kSecReturnAttributes=YES or multi-item query)
    if (resultType == CFArrayGetTypeID()) {
        NSArray *items = (__bridge NSArray *)(*result);
        NSMutableArray *patched = [NSMutableArray arrayWithCapacity:items.count];
        BOOL changed = NO;
        for (id item in items) {
            if (![item isKindOfClass:[NSDictionary class]]) {
                [patched addObject:item];
                continue;
            }
            NSDictionary *dict = (NSDictionary *)item;
            NSMutableDictionary *mDict = [dict mutableCopy];
            // Check kSecValueData
            NSData *vData = mDict[(__bridge id)kSecValueData];
            if ([vData isKindOfClass:[NSData class]]) {
                NSString *sv = [[NSString alloc] initWithData:vData encoding:NSUTF8StringEncoding];
                BOOL isHash = isHex64(sv);
                [sv release];
                if (isHash) {
                    mDict[(__bridge id)kSecValueData] =
                        [sCustomDeviceID dataUsingEncoding:NSUTF8StringEncoding];
                    changed = YES;
                }
            }
            NSDictionary *copied = [mDict copy];
            [patched addObject:copied];
            [copied release];
            [mDict release];
        }
        if (changed) {
            CFRelease(*result);
            *result = (CFTypeRef)[patched copy];
        }
        return status;
    }

    // Result is a single dictionary of attributes
    if (resultType == CFDictionaryGetTypeID()) {
        NSDictionary *dict = (__bridge NSDictionary *)(*result);
        NSMutableDictionary *mDict = [dict mutableCopy];
        BOOL changed = NO;

        for (id key in dict) {
            id val = mDict[key];
            if ([val isKindOfClass:[NSString class]] && isHex64((NSString *)val)) {
                mDict[key] = sCustomDeviceID;
                changed = YES;
            } else if ([val isKindOfClass:[NSData class]]) {
                NSString *sv = [[NSString alloc] initWithData:val encoding:NSUTF8StringEncoding];
                BOOL isHash = isHex64(sv);
                [sv release];
                if (isHash) {
                    mDict[key] = [sCustomDeviceID dataUsingEncoding:NSUTF8StringEncoding];
                    changed = YES;
                }
            }
        }

        if (changed) {
            CFRelease(*result);
            NSDictionary *patched = [mDict copy];
            *result = (CFTypeRef)patched;
        }
        [mDict release];
    }

    return status;
}

DYLD_INTERPOSE(my_SecItemCopyMatching, SecItemCopyMatching)

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Keychain write interpose – SecItemAdd / SecItemUpdate
// When an app writes a 64-char hex device fingerprint to the keychain for the
// first time (SecItemAdd) or updates it (SecItemUpdate), replace the value
// with the user-configured custom device ID so the stored value is immediately
// our fake ID.  This prevents the app from persisting the real hardware ID
// before our read-side hook ever fires.
// ─────────────────────────────────────────────────────────────────────────────

/// Replaces any 64-char hex kSecValueData in attrs with the custom device ID.
/// Returns a new retained dictionary, or nil if nothing changed.
static CFDictionaryRef PatchKeychainWriteAttrs(CFDictionaryRef attrs) {
    if (!sTweakEnabled || !sCustomDeviceID || sCustomDeviceID.length == 0)
        return nil;

    NSDictionary *d = (__bridge NSDictionary *)attrs;
    id vData = d[(__bridge id)kSecValueData];
    NSString *strVal = nil;

    if ([vData isKindOfClass:[NSData class]]) {
        strVal = [[NSString alloc] initWithData:(NSData *)vData
                                      encoding:NSUTF8StringEncoding];
    } else if ([vData isKindOfClass:[NSString class]]) {
        strVal = (NSString *)vData;
    }

    if (!isHex64(strVal)) return nil;

    NSMutableDictionary *m = [d mutableCopy];
    m[(__bridge id)kSecValueData] =
        [sCustomDeviceID dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *patched = [m copy];
    [m release];
    return (CFDictionaryRef)patched;
}

static OSStatus my_SecItemAdd(CFDictionaryRef attrs, CFTypeRef *result) {
    CFDictionaryRef patched = PatchKeychainWriteAttrs(attrs);
    OSStatus st = SecItemAdd(patched ? patched : attrs, result);
    if (patched) CFRelease(patched);
    return st;
}

static OSStatus my_SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attrs) {
    CFDictionaryRef patched = PatchKeychainWriteAttrs(attrs);
    OSStatus st = SecItemUpdate(query, patched ? patched : attrs);
    if (patched) CFRelease(patched);
    return st;
}

DYLD_INTERPOSE(my_SecItemAdd,    SecItemAdd)
DYLD_INTERPOSE(my_SecItemUpdate, SecItemUpdate)

// ─────────────────────────────────────────────────────────────────────────────
// MARK: NSUserDefaults hooks
// Many apps compute a SHA-256 device fingerprint on first launch and cache it
// in NSUserDefaults.  Swizzle -stringForKey:, -objectForKey:, and -dataForKey:
// 64-char hex value stored under ANY key is transparently replaced with the
// user-configured custom device ID.
// ─────────────────────────────────────────────────────────────────────────────

static IMP sOrigStringForKey  = NULL;
static IMP sOrigObjectForKey  = NULL;
static IMP sOrigDataForKey    = NULL;

static NSString *Hooked_stringForKey(NSUserDefaults *self, SEL _cmd, NSString *key) {
    NSString *val = ((NSString *(*)(id, SEL, NSString *))sOrigStringForKey)(self, _cmd, key);
    if (sTweakEnabled && sCustomDeviceID.length > 0 && isHex64(val))
        return sCustomDeviceID;
    return val;
}

static id Hooked_objectForKey(NSUserDefaults *self, SEL _cmd, NSString *key) {
    id val = ((id (*)(id, SEL, NSString *))sOrigObjectForKey)(self, _cmd, key);
    if (sTweakEnabled && sCustomDeviceID.length > 0 &&
        [val isKindOfClass:[NSString class]] && isHex64((NSString *)val))
        return sCustomDeviceID;
    return val;
}

static NSData *Hooked_dataForKey(NSUserDefaults *self, SEL _cmd, NSString *key) {
    NSData *val = ((NSData *(*)(id, SEL, NSString *))sOrigDataForKey)(self, _cmd, key);
    if (!sTweakEnabled || sCustomDeviceID.length == 0 || ![val isKindOfClass:[NSData class]])
        return val;

    NSString *decoded = [[NSString alloc] initWithData:val encoding:NSUTF8StringEncoding];
    BOOL shouldPatch = isHex64(decoded);
    [decoded release];
    if (shouldPatch) return [sCustomDeviceID dataUsingEncoding:NSUTF8StringEncoding];
    return val;
}

static void InstallUserDefaultsHooks(void) {
    Class cls = [NSUserDefaults class];

    SEL selStr = @selector(stringForKey:);
    Method mStr = class_getInstanceMethod(cls, selStr);
    if (mStr) {
        sOrigStringForKey = method_getImplementation(mStr);
        method_setImplementation(mStr, (IMP)Hooked_stringForKey);
    }

    SEL selObj = @selector(objectForKey:);
    Method mObj = class_getInstanceMethod(cls, selObj);
    if (mObj) {
        sOrigObjectForKey = method_getImplementation(mObj);
        method_setImplementation(mObj, (IMP)Hooked_objectForKey);
    }

    SEL selData = @selector(dataForKey:);
    Method mData = class_getInstanceMethod(cls, selData);
    if (mData) {
        sOrigDataForKey = method_getImplementation(mData);
        method_setImplementation(mData, (IMP)Hooked_dataForKey);
    }

    NSLog(@"[DeviceIDSpoofer] NSUserDefaults hooks installed ✓");
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Constructor – runs when the dylib is injected into any process
// ─────────────────────────────────────────────────────────────────────────────

__attribute__((constructor))
static void DeviceIDSpooferInit(void) {
    LoadSettings();
    InstallHooks();
    NSLog(@"[DeviceIDSpoofer] Loaded  |  Tweak %@  |  UDID=%@  IDFA=%@  IDFV=%@  DeviceID=%@",
          sTweakEnabled ? @"ENABLED ✅" : @"DISABLED ❌",
          sCustomUDID ?: @"(real)",
          sCustomIDFA ?: @"(real)",
          sCustomIDFV ?: @"(real)",
          sCustomDeviceID ?: @"(real)");

    // Wait for the app to finish launching, then add the floating button
    [[NSNotificationCenter defaultCenter]
        addObserverForName:UIApplicationDidFinishLaunchingNotification
                    object:nil
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *n) {
            dispatch_after(
                dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                dispatch_get_main_queue(), ^{
                    [[DeviceIDSettingsViewController sharedInstance] addFloatingButton];
                });
        }];

    // Fallback: if the notification fired before we registered, try again later
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            [[DeviceIDSettingsViewController sharedInstance] addFloatingButton];
        });
}
