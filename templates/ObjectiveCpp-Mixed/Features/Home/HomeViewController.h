#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// The root screen. It drives the C++ statistics engine through the pure-ObjC
/// `EngineBridge` and renders the computed mean and standard deviation.
@interface HomeViewController : UIViewController

@end

NS_ASSUME_NONNULL_END
