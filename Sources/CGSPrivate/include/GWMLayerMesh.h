#ifdef __OBJC__
#import <QuartzCore/QuartzCore.h>
NS_ASSUME_NONNULL_BEGIN
BOOL GWMLayerMeshAvailable(void);
id _Nullable GWMCreateLayerMesh(const CGPoint *from, const CGPoint *to, NSUInteger columns, NSUInteger rows);
BOOL GWMApplyLayerMesh(CALayer *layer, id _Nullable mesh);
BOOL GWMAnimateLayerMesh(CALayer *layer, NSArray *values, NSArray<NSNumber *> *times, CFTimeInterval duration, NSString *key);
NS_ASSUME_NONNULL_END
#endif
