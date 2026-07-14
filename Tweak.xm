#import <substrate.h>
#import <UIKit/UIKit.h>

static NSString *customUDID = nil;
static NSString *customIDFA = nil;
static NSString *customIDFV = nil;
static BOOL tweakEnabled = YES;

static void loadCustomValues() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    customUDID = [defaults stringForKey:@"com.deviceid.custom.udid"];
    customIDFA = [defaults stringForKey:@"com.deviceid.custom.idfa"];
    customIDFV = [defaults stringForKey:@"com.deviceid.custom.idfv"];
    tweakEnabled = [defaults boolForKey:@"com.deviceid.enabled"] ?: YES;
}

@interface DeviceIDSettingsViewController : UITableViewController
+ (instancetype)sharedInstance;
- (void)addSettingsButton;
@end

@implementation DeviceIDSettingsViewController

static DeviceIDSettingsViewController *_sharedInstance = nil;

+ (instancetype)sharedInstance {
    if (!_sharedInstance) {
        _sharedInstance = [[self alloc] initWithStyle:UITableViewStyleGrouped];
        _sharedInstance.title = @"Device ID Spoofer";
    }
    return _sharedInstance;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismiss)];
}

- (void)dismiss {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)addSettingsButton {
    UIWindow *window = nil;
    
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                for (UIWindow *w in scene.windows) {
                    if (w.isKeyWindow) {
                        window = w;
                        break;
                    }
                }
            }
        }
    } else {
        window = [[UIApplication sharedApplication] valueForKey:@"keyWindow"];
    }
    
    if (!window) return;
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(window.bounds.size.width - 70, window.bounds.size.height - 130, 60, 60);
    btn.backgroundColor = [UIColor colorWithRed:0.3 green:0.85 blue:0.4 alpha:0.95];
    btn.layer.cornerRadius = 30;
    [btn setTitle:@"⚙️" forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:28];
    [btn addTarget:self action:@selector(showPanel) forControlEvents:UIControlEventTouchUpInside];
    
    [window addSubview:btn];
}

- (void)showPanel {
    UIWindow *window = nil;
    
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                for (UIWindow *w in scene.windows) {
                    if (w.isKeyWindow) {
                        window = w;
                        break;
                    }
                }
            }
        }
    } else {
        window = [[UIApplication sharedApplication] valueForKey:@"keyWindow"];
    }
    
    if (!window) return;
    
    UIViewController *root = window.rootViewController;
    if (!root) return;
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:self];
    [root presentViewController:nav animated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;
    if (section == 1) return 3;
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"Status";
    if (section == 1) return @"Custom IDs";
    return @"Actions";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
    
    if (indexPath.section == 0) {
        cell.textLabel.text = @"Enabled";
        UISwitch *toggle = [[UISwitch alloc] init];
        toggle.on = tweakEnabled;
        [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
    } else if (indexPath.section == 1) {
        NSArray *labels = @[@"UDID", @"IDFA", @"IDFV"];
        NSArray *keys = @[@"com.deviceid.custom.udid", @"com.deviceid.custom.idfa", @"com.deviceid.custom.idfv"];
        cell.textLabel.text = labels[indexPath.row];
        NSString *val = [[NSUserDefaults standardUserDefaults] stringForKey:keys[indexPath.row]];
        cell.detailTextLabel.text = val ? @"SET" : @"Not Set";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        NSArray *actions = @[@"Generate Random", @"Reset All"];
        cell.textLabel.text = actions[indexPath.row];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 1) {
        [self editID:indexPath.row];
    } else if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            [self generateRandom];
        } else {
            [self resetAll];
        }
    }
}

- (void)toggleChanged:(UISwitch *)toggle {
    tweakEnabled = toggle.on;
    [[NSUserDefaults standardUserDefaults] setBool:tweakEnabled forKey:@"com.deviceid.enabled"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)editID:(NSInteger)index {
    NSArray *titles = @[@"UDID", @"IDFA", @"IDFV"];
    NSArray *keys = @[@"com.deviceid.custom.udid", @"com.deviceid.custom.idfa", @"com.deviceid.custom.idfv"];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Edit %@", titles[index]] message:@"Enter new value" preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        NSString *val = [[NSUserDefaults standardUserDefaults] stringForKey:keys[index]];
        field.text = val ?: @"";
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *value = alert.textFields[0].text;
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if (value.length > 0) {
            [defaults setObject:value forKey:keys[index]];
        } else {
            [defaults removeObjectForKey:keys[index]];
        }
        [defaults synchronize];
        loadCustomValues();
        [self.tableView reloadData];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)generateRandom {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSUUID *uuid1 = [NSUUID UUID];
    NSUUID *uuid2 = [NSUUID UUID];
    NSUUID *uuid3 = [NSUUID UUID];
    
    [defaults setObject:uuid1.UUIDString forKey:@"com.deviceid.custom.udid"];
    [defaults setObject:uuid2.UUIDString forKey:@"com.deviceid.custom.idfa"];
    [defaults setObject:uuid3.UUIDString forKey:@"com.deviceid.custom.idfv"];
    [defaults synchronize];
    loadCustomValues();
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Success" message:@"Random IDs generated" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self.tableView reloadData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)resetAll {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:@"com.deviceid.custom.udid"];
    [defaults removeObjectForKey:@"com.deviceid.custom.idfa"];
    [defaults removeObjectForKey:@"com.deviceid.custom.idfv"];
    [defaults synchronize];
    loadCustomValues();
    [self.tableView reloadData];
}

@end

%hook UIApplication
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[DeviceIDSettingsViewController sharedInstance] addSettingsButton];
    });
    return result;
}
%end

%hook UIDevice
- (NSString *)uniqueIdentifier {
    if (!tweakEnabled) return %orig;
    if (customUDID) return customUDID;
    return %orig;
}
%end

%hook UIDevice
- (NSUUID *)identifierForVendor {
    if (!tweakEnabled) return %orig;
    if (customIDFV) {
        return [[NSUUID alloc] initWithUUIDString:customIDFV];
    }
    return %orig;
}
%end

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    if (!tweakEnabled) return %orig;
    if (customIDFA) {
        return [[NSUUID alloc] initWithUUIDString:customIDFA];
    }
    return %orig;
}
%end

%ctor {
    loadCustomValues();
    NSLog(@"[DeviceIDSpoofer] Tweak loaded!");
}
