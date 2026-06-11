//
//  SceneDelegate.h
//  ObjectiveC-UIKit
//
//  Owns the UIWindow for a single scene and builds the initial UI hierarchy
//  programmatically (no storyboard).
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SceneDelegate : UIResponder <UIWindowSceneDelegate>

@property (nonatomic, strong, nullable) UIWindow *window;

@end

NS_ASSUME_NONNULL_END
