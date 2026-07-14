#import <substrate.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// Forward declarations
@class DeviceIDSettingsViewController;

%hook UIApplicationDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;
    
    // Add settings button after delay
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[DeviceIDSettingsViewController sharedInstance] addSettingsButton];
    });
    
    return result;
}
%end

// Main Settings View Controller
@interface DeviceIDSettingsViewController : UITableViewController <UITextFieldDelegate>
+ (instancetype)sharedInstance;
- (void)addSettingsButton;
- (void)showSettings;
@end

@implementation DeviceIDSettingsViewController

static DeviceIDSettingsViewController *_sharedInstance = nil;

+ (instancetype)sharedInstance {
    if (!_sharedInstance) {
        _sharedInstance = [[self alloc] initWithStyle:UITableViewStyleGrouped];
    }
    return _sharedInstance;
}

- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self) {
        self.title = @"🎛️ Device ID Spoofer";
    }
    return self;
}

- (void)addSettingsButton {
    UIWindow *keyWindow = nil;
    
    // Get the key window safely
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                keyWindow = scene.windows.firstObject;
                if (keyWindow) break;
            }
        }
    } else {
        keyWindow = [UIApplication sharedApplication].keyWindow;
    }
    
    if (!keyWindow) return;
    
    // Create floating settings button
    UIButton *settingsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    settingsButton.frame = CGRectMake(keyWindow.bounds.size.width - 70, keyWindow.bounds.size.height - 120, 60, 60);
    settingsButton.backgroundColor = [UIColor colorWithRed:0.3 green:0.85 blue:0.4 alpha:0.95];
    settingsButton.layer.cornerRadius = 30;
    settingsButton.clipsToBounds = YES;
    settingsButton.layer.shadowColor = [UIColor blackColor].CGColor;
    settingsButton.layer.shadowOpacity = 0.5;
    settingsButton.layer.shadowRadius = 5;
    settingsButton.layer.shadowOffset = CGSizeMake(0, 2);
    
    // Add icon/text
    [settingsButton setTitle:@"⚙️" forState:UIControlStateNormal];
    settingsButton.titleLabel.font = [UIFont systemFontOfSize:28];
    
    [settingsButton addTarget:self action:@selector(showSettings) forControlEvents:UIControlEventTouchUpInside];
    
    // Make button draggable
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [settingsButton addGestureRecognizer:panGesture];
    
    [keyWindow addSubview:settingsButton];
    
    NSLog(@"[DeviceIDSpoofer] Settings button added successfully");
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    UIView *button = gesture.view;
    CGPoint translation = [gesture translationInView:button.superview];
    
    button.center = CGPointMake(button.center.x + translation.x, button.center.y + translation.y);
    
    [gesture setTranslation:CGPointZero inView:button.superview];
}

- (void)showSettings {
    NSLog(@"[DeviceIDSpoofer] Opening settings");
    
    UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    if (!rootVC) return;
    
    // Create navigation controller
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:self];
    
    // Setup navigation bar
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(closeSettings)];
    
    [rootVC presentViewController:navController animated:YES completion:nil];
}

- (void)closeSettings {
    [self dismissViewControllerAnimated:YES completion:nil];
}

// MARK: - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 1; // معلومات الجهاز الحالي
    } else if (section == 1) {
        return 5; // UDID, IDFA, IDFV, Serial, MAC
    } else {
        return 2; // Generate, Reset
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return @"📱 معلومات الجهاز";
    } else if (section == 1) {
        return @"🔧 تخصيص المعرفات";
    } else {
        return @"⚡ إجراءات";
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
    }
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    if (indexPath.section == 0) {
        // Current device info
        cell.textLabel.text = @"المعرف الحالي:";
        NSUUID *idfv = [[UIDevice currentDevice] identifierForVendor];
        cell.detailTextLabel.text = idfv.UUIDString;
        cell.detailTextLabel.numberOfLines = 2;
        cell.detailTextLabel.textColor = [UIColor systemGrayColor];
        cell.userInteractionEnabled = NO;
    } else if (indexPath.section == 1) {
        // Custom ID fields
        NSArray *titles = @[@"UDID", @"IDFA", @"IDFV", @"رقم التسلسل", @"MAC"];
        NSArray *keys = @[@"com.deviceid.custom.udid", @"com.deviceid.custom.idfa", @"com.deviceid.custom.idfv", @"com.deviceid.custom.serial", @"com.deviceid.custom.mac"];
        
        cell.textLabel.text = titles[indexPath.row];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *currentValue = [defaults objectForKey:keys[indexPath.row]];
        cell.detailTextLabel.text = currentValue ? [currentValue substringToIndex:MIN(20, currentValue.length)] : @"لم يتم التعيين";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.userInteractionEnabled = YES;
    } else {
        // Actions
        NSArray *actions = @[@"توليد معرفات عشوائية", @"إعادة تعيين الكل"];
        cell.textLabel.text = actions[indexPath.row];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 1) {
        [self showEditDialogForIndex:indexPath.row];
    } else if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            [self generateRandomIDs];
        } else {
            [self resetAllIDs];
        }
    }
}

// MARK: - Edit Dialog

- (void)showEditDialogForIndex:(NSInteger)index {
    NSArray *titles = @[@"UDID", @"IDFA", @"IDFV", @"رقم التسلسل", @"MAC"];
    NSArray *keys = @[@"com.deviceid.custom.udid", @"com.deviceid.custom.idfa", @"com.deviceid.custom.idfv", @"com.deviceid.custom.serial", @"com.deviceid.custom.mac"];
    NSArray *placeholders = @[@"أدخل UDID (40 حرف)", @"أدخل UUID للإعلانات", @"أدخل UUID للبائع", @"أدخل رقم التسلسل", @"أدخل عنوان MAC"];
    
    NSString *title = titles[index];
    NSString *key = keys[index];
    NSString *placeholder = placeholders[index];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"تعديل %@", title] message:@"أدخل القيمة الجديدة" preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = placeholder;
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *currentValue = [defaults objectForKey:key];
        textField.text = currentValue ?: @"";
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    
    // Add clear button
    [alert addAction:[UIAlertAction actionWithTitle:@"مسح" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults removeObjectForKey:key];
        [defaults synchronize];
        NSLog(@"[DeviceIDSpoofer] Cleared: %@", key);
        [self.tableView reloadData];
    }]];
    
    // Add save button
    [alert addAction:[UIAlertAction actionWithTitle:@"حفظ" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UITextField *textField = alert.textFields.firstObject;
        NSString *value = textField.text;
        
        if (value.length == 0) {
            UIAlertController *emptyAlert = [UIAlertController alertControllerWithTitle:@"خطأ" message:@"الحقل فارغ" preferredStyle:UIAlertControllerStyleAlert];
            [emptyAlert addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:emptyAlert animated:YES completion:nil];
            return;
        }
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:value forKey:key];
        [defaults synchronize];
        
        NSLog(@"[DeviceIDSpoofer] Saved %@: %@", title, value);
        
        // Show success alert
        UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"تم الحفظ" message:[NSString stringWithFormat:@"تم حفظ %@ بنجاح", title] preferredStyle:UIAlertControllerStyleAlert];
        [successAlert addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self.tableView reloadData];
        }]];
        [self presentViewController:successAlert animated:YES completion:nil];
    }]];
    
    // Add cancel button
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

// MARK: - Actions

- (void)generateRandomIDs {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"توليد معرفات عشوائية" message:@"هل تريد توليد معرفات عشوائية جديدة؟" preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"نعم" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        // Generate random UUIDs
        NSUUID *uuid1 = [NSUUID UUID];
        NSUUID *uuid2 = [NSUUID UUID];
        NSUUID *uuid3 = [NSUUID UUID];
        NSString *randomSerial = [NSString stringWithFormat:@"SN%010d", arc4random_uniform(9999999999)];
        NSString *randomMAC = [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X", arc4random_uniform(256), arc4random_uniform(256), arc4random_uniform(256), arc4random_uniform(256), arc4random_uniform(256), arc4random_uniform(256)];
        
        [defaults setObject:uuid1.UUIDString forKey:@"com.deviceid.custom.udid"];
        [defaults setObject:uuid2.UUIDString forKey:@"com.deviceid.custom.idfa"];
        [defaults setObject:uuid3.UUIDString forKey:@"com.deviceid.custom.idfv"];
        [defaults setObject:randomSerial forKey:@"com.deviceid.custom.serial"];
        [defaults setObject:randomMAC forKey:@"com.deviceid.custom.mac"];
        [defaults synchronize];
        
        NSLog(@"[DeviceIDSpoofer] Generated new random IDs");
        
        UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"تم التوليد" message:@"تم توليد معرفات عشوائية جديدة بنجاح" preferredStyle:UIAlertControllerStyleAlert];
        [successAlert addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self.tableView reloadData];
        }]];
        [self presentViewController:successAlert animated:YES completion:nil];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"لا" style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)resetAllIDs {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"إعادة تعيين" message:@"هل تريد حذف جميع المعرفات المخصصة؟" preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"نعم" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults removeObjectForKey:@"com.deviceid.custom.udid"];
        [defaults removeObjectForKey:@"com.deviceid.custom.idfa"];
        [defaults removeObjectForKey:@"com.deviceid.custom.idfv"];
        [defaults removeObjectForKey:@"com.deviceid.custom.serial"];
        [defaults removeObjectForKey:@"com.deviceid.custom.mac"];
        [defaults synchronize];
        
        NSLog(@"[DeviceIDSpoofer] Reset all custom IDs");
        
        UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"تم الحذف" message:@"تم حذف جميع المعرفات المخصصة" preferredStyle:UIAlertControllerStyleAlert];
        [successAlert addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self.tableView reloadData];
        }]];
        [self presentViewController:successAlert animated:YES completion:nil];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"لا" style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

@end
