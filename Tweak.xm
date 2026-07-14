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

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Constants & State
// ─────────────────────────────────────────────────────────────────────────────

static NSString * const kUDIDKey    = @"com.deviceid.custom.udid";
static NSString * const kIDFAKey    = @"com.deviceid.custom.idfa";
static NSString * const kIDFVKey    = @"com.deviceid.custom.idfv";
static NSString * const kEnabledKey = @"com.deviceid.enabled";

static NSString *sCustomUDID = nil;
static NSString *sCustomIDFA = nil;
static NSString *sCustomIDFV = nil;
static BOOL      sTweakEnabled = YES;

static void LoadSettings(void) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    sCustomUDID = [d stringForKey:kUDIDKey];
    sCustomIDFA = [d stringForKey:kIDFAKey];
    sCustomIDFV = [d stringForKey:kIDFVKey];
    id en = [d objectForKey:kEnabledKey];
    sTweakEnabled = en ? [d boolForKey:kEnabledKey] : YES;
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
    UIWindow *win = [self activeKeyWindow];
    if (!win) return;

    // Only add once per window
    for (UIView *v in win.subviews) {
        if (v.tag == 0xDEC0DE) return;
    }

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
    if (s == 1) return 3;   // UDID · IDFA · IDFV
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
        NSArray *titles = @[@"UDID", @"IDFA", @"IDFV"];
        NSArray *keys   = @[kUDIDKey, kIDFAKey, kIDFVKey];
        NSString *val = [[NSUserDefaults standardUserDefaults] stringForKey:keys[ip.row]];

        cell.textLabel.text = titles[ip.row];
        if (val.length > 0) {
            NSUInteger maxLen = MIN((NSUInteger)28, val.length);
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
// MARK: Actions
// ─────────────────────────────────────────────────────────────────────────────

- (void)toggleEnabled:(UISwitch *)sw {
    sTweakEnabled = sw.on;
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setBool:sTweakEnabled forKey:kEnabledKey];
    [d synchronize];
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0]
                  withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)editIDAtIndex:(NSInteger)idx {
    NSArray *titles = @[@"UDID", @"IDFA", @"IDFV"];
    NSArray *keys   = @[kUDIDKey, kIDFAKey, kIDFVKey];
    NSArray *hints  = @[
        @"مثال: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
        @"مثال: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
        @"مثال: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
    ];
    NSString *key = keys[idx];

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:[NSString stringWithFormat:@"تعديل %@", titles[idx]]
                         message:@"أدخل القيمة الجديدة (اتركه فارغاً للحذف)"
                  preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder              = hints[idx];
        tf.text                     = [[NSUserDefaults standardUserDefaults] stringForKey:key] ?: @"";
        tf.autocorrectionType       = UITextAutocorrectionTypeNo;
        tf.autocapitalizationType   = UITextAutocapitalizationTypeNone;
    }];

    [alert addAction:[UIAlertAction
        actionWithTitle:@"حفظ"
                  style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *a) {
        NSString *v = alert.textFields.firstObject.text;
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        if (v.length > 0) [d setObject:v forKey:key];
        else              [d removeObjectForKey:key];
        [d synchronize];
        LoadSettings();
        [self.tableView reloadData];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)generateRandomIDs {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setObject:[NSUUID UUID].UUIDString forKey:kUDIDKey];
    [d setObject:[NSUUID UUID].UUIDString forKey:kIDFAKey];
    [d setObject:[NSUUID UUID].UUIDString forKey:kIDFVKey];
    [d synchronize];
    LoadSettings();

    UIAlertController *ok = [UIAlertController
        alertControllerWithTitle:@"✅ تم التوليد"
                         message:@"تم توليد معرفات عشوائية جديدة بنجاح"
                  preferredStyle:UIAlertControllerStyleAlert];
    [ok addAction:[UIAlertAction actionWithTitle:@"حسناً"
                                           style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction *a) {
        [self.tableView reloadData];
    }]];
    [self presentViewController:ok animated:YES completion:nil];
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
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        [d removeObjectForKey:kUDIDKey];
        [d removeObjectForKey:kIDFAKey];
        [d removeObjectForKey:kIDFVKey];
        [d synchronize];
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
    }

    // UIDevice – identifierForVendor (IDFV)
    SEL idfvSel = @selector(identifierForVendor);
    Method idfvM = class_getInstanceMethod(uiDeviceClass, idfvSel);
    if (idfvM) {
        sOrigIdentifierForVendor =
            (IdentifierForVendorIMP)method_getImplementation(idfvM);
        method_setImplementation(idfvM, (IMP)Hooked_identifierForVendor);
    }

    // ASIdentifierManager – advertisingIdentifier (IDFA)
    // Use NSClassFromString to avoid requiring AdSupport at link time
    Class asmClass = NSClassFromString(@"ASIdentifierManager");
    if (asmClass) {
        SEL idfaSel = NSSelectorFromString(@"advertisingIdentifier");
        Method idfaM = class_getInstanceMethod(asmClass, idfaSel);
        if (idfaM) {
            sOrigAdvertisingId =
                (AdvertisingIdentifierIMP)method_getImplementation(idfaM);
            method_setImplementation(idfaM, (IMP)Hooked_advertisingIdentifier);
        }
    }

    NSLog(@"[DeviceIDSpoofer] Hooks installed ✓");
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Constructor – runs when the dylib is injected into any process
// ─────────────────────────────────────────────────────────────────────────────

__attribute__((constructor))
static void DeviceIDSpooferInit(void) {
    LoadSettings();
    InstallHooks();
    NSLog(@"[DeviceIDSpoofer] Loaded  |  Tweak %@",
          sTweakEnabled ? @"ENABLED ✅" : @"DISABLED ❌");

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
