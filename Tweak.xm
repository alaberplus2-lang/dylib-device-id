#import <substrate.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <sys/utsname.h>

// Forward declarations
@class DeviceIDSettingsViewController;

// Global variables for custom IDs
static NSString *customUDID = nil;
static NSString *customIDFA = nil;
static NSString *customIDFV = nil;
static NSString *customSerial = nil;
static NSString *customMAC = nil;
static BOOL tweakEnabled = YES;

// Load custom values from NSUserDefaults
static void loadCustomValues() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    customUDID = [defaults stringForKey:@"com.deviceid.custom.udid"];
    customIDFA = [defaults stringForKey:@"com.deviceid.custom.idfa"];
    customIDFV = [defaults stringForKey:@"com.deviceid.custom.idfv"];
    customSerial = [defaults stringForKey:@"com.deviceid.custom.serial"];
    customMAC = [defaults stringForKey:@"com.deviceid.custom.mac"];
    tweakEnabled = [defaults boolForKey:@"com.deviceid.enabled"] ?: YES;
    
    NSLog(@"[DeviceIDSpoofer] ✅ Custom values loaded - UDID: %@, IDFA: %@, IDFV: %@", 
          customUDID ? @"SET" : @"NOT SET",
          customIDFA ? @"SET" : @"NOT SET",
          customIDFV ? @"SET" : @"NOT SET");
}

// Main Settings View Controller
@interface DeviceIDSettingsViewController : UITableViewController
+ (instancetype)sharedInstance;
- (void)addSettingsButton;
- (void)showSettings;
@end

@implementation DeviceIDSettingsViewController

static DeviceIDSettingsViewController *_sharedInstance = nil;

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] initWithStyle:UITableViewStyleGrouped];
    });
    return _sharedInstance;
}

- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self) {
        self.title = @"🎛️ Device ID Spoofer";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(closeSettings)];
    self.tableView.backgroundColor = [UIColor systemBackgroundColor];
}

- (void)addSettingsButton {
    UIWindow *keyWindow = nil;
    
    if (@available(iOS 13.0, *)) {
        NSSet *scenes = [UIApplication sharedApplication].connectedScenes;
        for (UIWindowScene *scene in scenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) {
                        keyWindow = window;
                        break;
                    }
                }
                if (keyWindow) break;
            }
        }
    } else {
        keyWindow = [UIApplication sharedApplication].keyWindow;
    }
    
    if (!keyWindow) {
        NSLog(@"[DeviceIDSpoofer] ⚠️ No key window found");
        return;
    }
    
    // Create floating settings button
    UIButton *settingsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    settingsButton.frame = CGRectMake(keyWindow.bounds.size.width - 75, keyWindow.bounds.size.height - 140, 65, 65);
    settingsButton.backgroundColor = [UIColor colorWithRed:0.25 green:0.82 blue:0.35 alpha:0.95];
    settingsButton.layer.cornerRadius = 32.5;
    settingsButton.clipsToBounds = YES;
    settingsButton.layer.shadowColor = [UIColor blackColor].CGColor;
    settingsButton.layer.shadowOpacity = 0.6;
    settingsButton.layer.shadowRadius = 8;
    settingsButton.layer.shadowOffset = CGSizeMake(0, 3);
    
    [settingsButton setTitle:@"⚙️" forState:UIControlStateNormal];
    settingsButton.titleLabel.font = [UIFont systemFontOfSize:32 weight:UIFontWeightBold];
    [settingsButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    [settingsButton addTarget:self action:@selector(showSettings) forControlEvents:UIControlEventTouchUpInside];
    
    // Make button draggable
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [settingsButton addGestureRecognizer:panGesture];
    
    [keyWindow addSubview:settingsButton];
    [keyWindow bringSubviewToFront:settingsButton];
    
    NSLog(@"[DeviceIDSpoofer] ✅ Settings button added successfully");
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    UIView *button = gesture.view;
    UIWindow *keyWindow = button.window;
    
    CGPoint translation = [gesture translationInView:keyWindow];
    CGPoint newCenter = CGPointMake(button.center.x + translation.x, button.center.y + translation.y);
    
    // Keep button within window bounds
    float buttonRadius = button.bounds.size.width / 2;
    newCenter.x = MAX(buttonRadius, MIN(keyWindow.bounds.size.width - buttonRadius, newCenter.x));
    newCenter.y = MAX(buttonRadius, MIN(keyWindow.bounds.size.height - buttonRadius, newCenter.y));
    
    button.center = newCenter;
    [gesture setTranslation:CGPointZero inView:keyWindow];
}

- (void)showSettings {
    NSLog(@"[DeviceIDSpoofer] 📱 Opening settings panel");
    
    UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    if (!rootVC) {
        NSLog(@"[DeviceIDSpoofer] ⚠️ No root view controller");
        return;
    }
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:self];
    navController.modalPresentationStyle = UIModalPresentationFormSheet;
    
    if (@available(iOS 16.0, *)) {
        if (@available(iOS 16.4, *)) {
            UISheetPresentationController *sheet = navController.sheetPresentationController;
            sheet.detents = @[[UISheetPresentationControllerDetent largeDetent]];
            sheet.prefersGrabberVisible = YES;
        }
    }
    
    [rootVC presentViewController:navController animated:YES completion:nil];
}

- (void)closeSettings {
    [self dismissViewControllerAnimated:YES completion:nil];
}

// MARK: - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 1; // Enable/Disable toggle
        case 1: return 1; // Current device info
        case 2: return 5; // UDID, IDFA, IDFV, Serial, MAC
        case 3: return 2; // Generate, Reset
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"🔌 الحالة";
        case 1: return @"📱 معلومات الجهاز";
        case 2: return @"🔧 تخصيص المعرفات";
        case 3: return @"⚡ إجراءات";
        default: return @"";
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"تفعيل أو تعطيل التوك بدون إزالته";
    } else if (section == 2) {
        return @"اضغط على أي معرف لتعديله يدويياً";
    }
    return @"";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"toggleCell"];
        cell.textLabel.text = @"تفعيل التوك";
        
        UISwitch *toggle = [[UISwitch alloc] init];
        toggle.on = tweakEnabled;
        toggle.tag = 999;
        [toggle addTarget:self action:@selector(toggleTweak:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
        
        return cell;
    }
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    if (indexPath.section == 1) {
        // Current device info
        cell.textLabel.text = @"معرف الجهاز الحالي:";
        cell.textLabel.font = [UIFont boldSystemFontOfSize:13];
        
        NSUUID *idfv = [[UIDevice currentDevice] identifierForVendor];
        NSString *deviceInfo = idfv.UUIDString ?: @"لا يتوفر";
        
        cell.detailTextLabel.text = deviceInfo;
        cell.detailTextLabel.numberOfLines = 2;
        cell.detailTextLabel.textColor = [UIColor systemGrayColor];
        cell.detailTextLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
        cell.userInteractionEnabled = NO;
    } else if (indexPath.section == 2) {
        // Custom ID fields
        NSArray *titles = @[@"UDID", @"IDFA", @"IDFV", @"رقم التسلسل", @"MAC Address"];
        NSArray *keys = @[@"com.deviceid.custom.udid", @"com.deviceid.custom.idfa", @"com.deviceid.custom.idfv", @"com.deviceid.custom.serial", @"com.deviceid.custom.mac"];
        NSArray *emojis = @[@"🔑", @"📊", @"🏢", @"🔢", @"🌐"];
        
        cell.textLabel.text = [NSString stringWithFormat:@"%@ %@", emojis[indexPath.row], titles[indexPath.row]];
        cell.textLabel.font = [UIFont boldSystemFontOfSize:13];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *currentValue = [defaults stringForKey:keys[indexPath.row]];
        
        if (currentValue) {
            NSString *preview = currentValue.length > 20 ? [currentValue substringToIndex:20] : currentValue;
            cell.detailTextLabel.text = [NSString stringWithFormat:@"✅ %@...", preview];
            cell.detailTextLabel.textColor = [UIColor systemGreenColor];
        } else {
            cell.detailTextLabel.text = @"❌ لم يتم التعيين - اضغط للتعديل";
            cell.detailTextLabel.textColor = [UIColor systemRedColor];
        }
        cell.detailTextLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.userInteractionEnabled = YES;
    } else if (indexPath.section == 3) {
        // Actions
        NSArray *actions = @[@"🎲 توليد معرفات عشوائية", @"🔄 إعادة تعيين الكل"];
        NSArray *colors = @[[UIColor systemBlueColor], [UIColor systemRedColor]];
        
        cell.textLabel.text = actions[indexPath.row];
        cell.textLabel.font = [UIFont boldSystemFontOfSize:13];
        cell.textLabel.textColor = colors[indexPath.row];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 2) {
        return 70;
    }
    return UITableViewAutomaticDimension;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 2) {
        [self showEditDialogForIndex:indexPath.row];
    } else if (indexPath.section == 3) {
        if (indexPath.row == 0) {
            [self generateRandomIDs];
        } else {
            [self resetAllIDs];
        }
    }
}

// MARK: - Toggle

- (void)toggleTweak:(UISwitch *)sender {
    tweakEnabled = sender.on;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:tweakEnabled forKey:@"com.deviceid.enabled"];
    [defaults synchronize];
    
    NSLog(@"[DeviceIDSpoofer] %@ توك %@", tweakEnabled ? @"✅" : @"❌", tweakEnabled ? @"مُفعّل" : @"معطّل");
}

// MARK: - Edit Dialog

- (void)showEditDialogForIndex:(NSInteger)index {
    NSArray *titles = @[@"UDID", @"IDFA", @"IDFV", @"رقم التسلسل", @"عنوان MAC"];
    NSArray *keys = @[@"com.deviceid.custom.udid", @"com.deviceid.custom.idfa", @"com.deviceid.custom.idfv", @"com.deviceid.custom.serial", @"com.deviceid.custom.mac"];
    NSArray *placeholders = @[
        @"أدخل UDID (32-40 حرف)",
        @"أدخل IDFA UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)",
        @"أدخل IDFV UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)",
        @"أدخل رقم التسلسل",
        @"أدخل عنوان MAC (XX:XX:XX:XX:XX:XX)"
    ];
    NSArray *descriptions = @[
        @"معرف فريد للجهاز",
        @"معرف الإعلانات",
        @"معرف البائع",
        @"رقم التسلسل",
        @"عنوان التحكم بالوصول إلى الوسيط"
    ];
    
    NSString *title = titles[index];
    NSString *key = keys[index];
    NSString *placeholder = placeholders[index];
    NSString *description = descriptions[index];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"تعديل %@", title] message:description preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = placeholder;
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *currentValue = [defaults stringForKey:key];
        textField.text = currentValue ?: @"";
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.spellCheckingType = UITextSpellCheckingTypeNo;
        
        if (index == 1 || index == 2) {
            textField.keyboardType = UIKeyboardTypeASCIICapable;
        }
    }];
    
    // Copy button
    [alert addAction:[UIAlertAction actionWithTitle:@"📋 نسخ" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *currentValue = [defaults stringForKey:key];
        if (currentValue) {
            [UIPasteboard generalPasteboard].string = currentValue;
            [self showAlert:@"تم النسخ" message:[NSString stringWithFormat:@"تم نسخ %@ إلى الحافظة", title]];
        }
    }]];
    
    // Clear button
    [alert addAction:[UIAlertAction actionWithTitle:@"🗑️ مسح" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults removeObjectForKey:key];
        [defaults synchronize];
        loadCustomValues();
        NSLog(@"[DeviceIDSpoofer] 🗑️ تم مسح: %@", key);
        [self.tableView reloadData];
    }]];
    
    // Save button
    [alert addAction:[UIAlertAction actionWithTitle:@"💾 حفظ" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UITextField *textField = alert.textFields.firstObject;
        NSString *value = textField.text.stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet];
        
        if (value.length == 0) {
            [self showAlert:@"خطأ" message:@"لا يمكن حفظ حقل فارغ"];
            return;
        }
        
        // Validate format
        if (![self validateValue:value forIndex:index]) {
            [self showAlert:@"صيغة غير صحيحة" message:[NSString stringWithFormat:@"الرجاء إدخال %@ بصيغة صحيحة", title]];
            return;
        }
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:value forKey:key];
        [defaults synchronize];
        loadCustomValues();
        
        NSLog(@"[DeviceIDSpoofer] ✅ تم حفظ %@: %@", title, value);
        [self showAlert:@"تم الحفظ ✅" message:[NSString stringWithFormat:@"تم حفظ %@ بنجاح", title]];
        [self.tableView reloadData];
    }]];
    
    // Cancel button
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (BOOL)validateValue:(NSString *)value forIndex:(NSInteger)index {
    switch (index) {
        case 0: // UDID
            return value.length >= 32 && value.length <= 40;
        case 1: // IDFA
        case 2: // IDFV
        {
            NSRegex *uuidRegex = [NSRegex regularExpressionWithPattern:@"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$" options:NSRegularExpressionCaseInsensitive error:nil];
            return [uuidRegex numberOfMatchesInString:value options:0 range:NSMakeRange(0, value.length)] > 0;
        }
        case 3: // Serial
            return value.length > 0;
        case 4: // MAC
        {
            NSRegex *macRegex = [NSRegex regularExpressionWithPattern:@"^([0-9A-F]{2}:){5}([0-9A-F]{2})$" options:NSRegularExpressionCaseInsensitive error:nil];
            return [macRegex numberOfMatchesInString:value options:0 range:NSMakeRange(0, value.length)] > 0;
        }
        default:
            return YES;
    }
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

// MARK: - Actions

- (void)generateRandomIDs {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"توليد معرفات عشوائية" message:@"اختر المعرفات التي تريد توليدها عشوائياً:" preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"جميع المعرفات" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self generateAllRandomIDs];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"UDID فقط" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self generateRandomUDID];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)generateAllRandomIDs {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSUUID *uuid1 = [NSUUID UUID];
    NSUUID *uuid2 = [NSUUID UUID];
    NSUUID *uuid3 = [NSUUID UUID];
    NSString *randomSerial = [NSString stringWithFormat:@"APPLE%010d", arc4random_uniform(9999999999)];
    NSString *randomMAC = [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X", arc4random_uniform(256), arc4random_uniform(256), arc4random_uniform(256), arc4random_uniform(256), arc4random_uniform(256), arc4random_uniform(256)];
    
    [defaults setObject:uuid1.UUIDString forKey:@"com.deviceid.custom.udid"];
    [defaults setObject:uuid2.UUIDString forKey:@"com.deviceid.custom.idfa"];
    [defaults setObject:uuid3.UUIDString forKey:@"com.deviceid.custom.idfv"];
    [defaults setObject:randomSerial forKey:@"com.deviceid.custom.serial"];
    [defaults setObject:randomMAC forKey:@"com.deviceid.custom.mac"];
    [defaults synchronize];
    
    loadCustomValues();
    NSLog(@"[DeviceIDSpoofer] 🎲 تم توليد معرفات عشوائية جديدة");
    
    [self showAlert:@"تم التوليد ✅" message:@"تم توليد معرفات عشوائية جديدة بنجاح"];
    [self.tableView reloadData];
}

- (void)generateRandomUDID {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSUUID *uuid = [NSUUID UUID];
    NSString *udid = [uuid.UUIDString stringByReplacingOccurrencesOfString:@"-" withString:@""].uppercaseString;
    
    [defaults setObject:udid forKey:@"com.deviceid.custom.udid"];
    [defaults synchronize];
    
    loadCustomValues();
    NSLog(@"[DeviceIDSpoofer] 🎲 تم توليد UDID جديد: %@", udid);
    
    [self showAlert:@"تم التوليد ✅" message:[NSString stringWithFormat:@"UDID الجديد:\n%@", udid]];
    [self.tableView reloadData];
}

- (void)resetAllIDs {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"تحذير" message:@"هل تريد فعلاً حذف جميع المعرفات المخصصة؟" preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"نعم، احذف الكل" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults removeObjectForKey:@"com.deviceid.custom.udid"];
        [defaults removeObjectForKey:@"com.deviceid.custom.idfa"];
        [defaults removeObjectForKey:@"com.deviceid.custom.idfv"];
        [defaults removeObjectForKey:@"com.deviceid.custom.serial"];
        [defaults removeObjectForKey:@"com.deviceid.custom.mac"];
        [defaults synchronize];
        
        loadCustomValues();
        NSLog(@"[DeviceIDSpoofer] 🔄 تم حذف جميع المعرفات المخصصة");
        
        [self showAlert:@"تم الحذف ✅" message:@"تم حذف جميع المعرفات المخصصة"];
        [self.tableView reloadData];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

@end

// MARK: - Hook UIApplicationDelegate to add button

%hook UIApplication
- (BOOL)setDelegate:(id<UIApplicationDelegate>)delegate {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[DeviceIDSettingsViewController sharedInstance] addSettingsButton];
    });
    return %orig;
}
%end

// MARK: - Main Hooks

// Hook UIDevice uniqueIdentifier (UDID)
%hook UIDevice
- (NSString *)uniqueIdentifier {
    if (!tweakEnabled) return %orig;
    NSString *result = customUDID ?: %orig;
    NSLog(@"[DeviceIDSpoofer] 🔑 UDID requested: %@", customUDID ? @"CUSTOM" : @"ORIGINAL");
    return result;
}
%end

// Hook identifierForVendor (IDFV)
%hook UIDevice
- (NSUUID *)identifierForVendor {
    if (!tweakEnabled) return %orig;
    if (customIDFV) {
        NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:customIDFV];
        NSLog(@"[DeviceIDSpoofer] 🏢 IDFV requested: CUSTOM");
        return uuid;
    }
    return %orig;
}
%end

// Hook ASIdentifierManager advertisingIdentifier (IDFA)
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    if (!tweakEnabled) return %orig;
    if (customIDFA) {
        NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:customIDFA];
        NSLog(@"[DeviceIDSpoofer] 📊 IDFA requested: CUSTOM");
        return uuid;
    }
    return %orig;
}
%end

%ctor {
    NSLog(@"[DeviceIDSpoofer] ==========================================");
    NSLog(@"[DeviceIDSpoofer] 🚀 Device ID Spoofer v2.0 تم تحميله");
    NSLog(@"[DeviceIDSpoofer] 📱 يدعم iOS 12.0 والإصدارات الأحدث");
    NSLog(@"[DeviceIDSpoofer] ==========================================");
    loadCustomValues();
}
