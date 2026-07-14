#import <Foundation/Foundation.h>

/// Helper class for setting up Objective-C runtime hooks.
@interface DeviceIDHooks : NSObject

/// Install all device-ID related hooks (called from the constructor).
+ (void)setupAllHooks;

@end
