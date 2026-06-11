//
//  SceneDelegate.m
//  ObjectiveC-UIKit
//

#import "SceneDelegate.h"
#import "HomeViewController.h"

@implementation SceneDelegate

#pragma mark - UIWindowSceneDelegate

- (void)scene:(UIScene *)scene
    willConnectToSession:(UISceneSession *)session
                 options:(UISceneConnectionOptions *)connectionOptions {
    // We build the entire UI in code, so guard for the expected scene type.
    if (![scene isKindOfClass:[UIWindowScene class]]) {
        return;
    }
    UIWindowScene *windowScene = (UIWindowScene *)scene;

    UIWindow *window = [[UIWindow alloc] initWithWindowScene:windowScene];

    // Root the app in a navigation controller hosting the Home screen.
    HomeViewController *home = [[HomeViewController alloc] init];
    UINavigationController *nav =
        [[UINavigationController alloc] initWithRootViewController:home];
    nav.navigationBar.prefersLargeTitles = YES;

    window.rootViewController = nav;
    self.window = window;
    [window makeKeyAndVisible];
}

- (void)sceneDidDisconnect:(UIScene *)scene {
    // TODO: Release resources tied to this scene; it may reconnect later.
}

- (void)sceneDidBecomeActive:(UIScene *)scene {
    // TODO: Restart any tasks paused (or not yet started) while inactive.
}

- (void)sceneWillResignActive:(UIScene *)scene {
    // TODO: Pause ongoing work as the scene moves away from active state.
}

- (void)sceneWillEnterForeground:(UIScene *)scene {
    // TODO: Undo changes made on entering the background.
}

- (void)sceneDidEnterBackground:(UIScene *)scene {
    // TODO: Save data and release shared resources.
}

@end
