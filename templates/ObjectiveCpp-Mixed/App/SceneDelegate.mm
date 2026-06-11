#import "SceneDelegate.h"
#import "HomeViewController.h"

@implementation SceneDelegate

- (void)scene:(UIScene *)scene
    willConnectToSession:(UISceneSession *)session
                 options:(UISceneConnectionOptions *)connectionOptions {
    UIWindowScene *windowScene = (UIWindowScene *)scene;
    if (![windowScene isKindOfClass:UIWindowScene.class]) {
        return;
    }

    self.window = [[UIWindow alloc] initWithWindowScene:windowScene];

    HomeViewController *home = [[HomeViewController alloc] init];
    UINavigationController *nav =
        [[UINavigationController alloc] initWithRootViewController:home];

    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
}

- (void)sceneDidDisconnect:(UIScene *)scene {
    // TODO: Release scene-specific resources.
}

@end
