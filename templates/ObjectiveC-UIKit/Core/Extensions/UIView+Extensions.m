//
//  UIView+Extensions.m
//  ObjectiveC-UIKit
//

#import "UIView+Extensions.h"

@implementation UIView (Extensions)

- (NSArray<NSLayoutConstraint *> *)pinEdgesToView:(UIView *)view {
    return [self pinEdgesToView:view insets:UIEdgeInsetsZero];
}

- (NSArray<NSLayoutConstraint *> *)pinEdgesToView:(UIView *)view
                                          insets:(UIEdgeInsets)insets {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    NSArray<NSLayoutConstraint *> *constraints = @[
        [self.topAnchor constraintEqualToAnchor:view.topAnchor
                                       constant:insets.top],
        [self.leadingAnchor constraintEqualToAnchor:view.leadingAnchor
                                           constant:insets.left],
        [self.trailingAnchor constraintEqualToAnchor:view.trailingAnchor
                                            constant:-insets.right],
        [self.bottomAnchor constraintEqualToAnchor:view.bottomAnchor
                                          constant:-insets.bottom],
    ];
    [NSLayoutConstraint activateConstraints:constraints];
    return constraints;
}

- (NSArray<NSLayoutConstraint *> *)pinEdgesToSafeAreaOfView:(UIView *)view {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    UILayoutGuide *guide = view.safeAreaLayoutGuide;
    NSArray<NSLayoutConstraint *> *constraints = @[
        [self.topAnchor constraintEqualToAnchor:guide.topAnchor],
        [self.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor],
        [self.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor],
        [self.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor],
    ];
    [NSLayoutConstraint activateConstraints:constraints];
    return constraints;
}

- (NSArray<NSLayoutConstraint *> *)centerInView:(UIView *)view {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    NSArray<NSLayoutConstraint *> *constraints = @[
        [self.centerXAnchor constraintEqualToAnchor:view.centerXAnchor],
        [self.centerYAnchor constraintEqualToAnchor:view.centerYAnchor],
    ];
    [NSLayoutConstraint activateConstraints:constraints];
    return constraints;
}

@end
