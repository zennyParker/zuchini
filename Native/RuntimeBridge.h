#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface ZucchiniRuntime : NSObject
@property(nonatomic, readonly) NSString *status;
@property(nonatomic, readonly) NSUInteger reads;
@property(nonatomic, readonly) NSUInteger writes;
- (nullable NSDictionary *)captureTarget:(NSString *)target fov:(double)fov NS_SWIFT_NAME(capture(target:fov:));
- (BOOL)applyX:(double)x y:(double)y z:(double)z targetID:(NSString *)targetID sequence:(uint64_t)sequence NS_SWIFT_NAME(apply(x:y:z:targetID:sequence:));
- (void)reset;
@end
NS_ASSUME_NONNULL_END
