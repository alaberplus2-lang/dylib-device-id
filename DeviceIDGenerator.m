#import "DeviceIDGenerator.h"
#import <Foundation/Foundation.h>

@implementation DeviceIDGenerator

+ (NSString *)generateFakeUDID {
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    NSString *uuidString = (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
    CFRelease(uuid);
    return [uuidString stringByReplacingOccurrencesOfString:@"-" withString:@""];
}

+ (NSString *)generateFakeIDFA {
    return [[NSUUID UUID] UUIDString];
}

+ (NSString *)generateFakeIDFV {
    return [[NSUUID UUID] UUIDString];
}

+ (NSString *)getPersistentIDForKey:(NSString *)key {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *savedID = [defaults objectForKey:key];
    
    if (savedID && savedID.length > 0) {
        return savedID;
    }
    
    NSString *newID = [[NSUUID UUID] UUIDString];
    [defaults setObject:newID forKey:key];
    [defaults synchronize];
    
    return newID;
}

@end
