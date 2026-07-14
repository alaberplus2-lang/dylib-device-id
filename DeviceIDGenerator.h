#import <Foundation/Foundation.h>

/// Utility class for generating and persisting fake device identifiers.
@interface DeviceIDGenerator : NSObject

/// Generates a random 40-character UDID-like hex string.
+ (NSString *)generateFakeUDID;

/// Generates a random UUID string suitable for IDFA.
+ (NSString *)generateFakeIDFA;

/// Generates a random UUID string suitable for IDFV.
+ (NSString *)generateFakeIDFV;

/// Returns a persistent fake ID stored under the given NSUserDefaults key,
/// creating a new UUID the first time.
+ (NSString *)getPersistentIDForKey:(NSString *)key;

@end
