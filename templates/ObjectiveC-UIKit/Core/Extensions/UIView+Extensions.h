//
//  UIView+Extensions.h
//  ObjectiveC-UIKit
//
//  Auto Layout convenience for programmatic UI. All methods disable
//  translatesAutoresizingMaskIntoConstraints on the receiver and return the
//  activated constraints so callers can store / animate them.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIView (Extensions)

/// Pins all four edges of the receiver to another view with no insets.
- (NSArray<NSLayoutConstraint *> *)pinEdgesToView:(UIView *)view;

/// Pins all four edges of the receiver to another view with the given insets.
- (NSArray<NSLayoutConstraint *> *)pinEdgesToView:(UIView *)view
                                          insets:(UIEdgeInsets)insets;

/// Pins all four edges to the safe area layout guide of another view.
- (NSArray<NSLayoutConstraint *> *)pinEdgesToSafeAreaOfView:(UIView *)view;

/// Centers the receiver within another view.
- (NSArray<NSLayoutConstraint *> *)centerInView:(UIView *)view;

@end

NS_ASSUME_NONNULL_END
