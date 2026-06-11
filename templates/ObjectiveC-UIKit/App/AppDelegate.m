//
//  AppDelegate.m
//  ObjectiveC-UIKit
//

#import "AppDelegate.h"

@implementation AppDelegate

#pragma mark - UIApplicationDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(nullable NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions {
    // TODO: Perform one-time, app-wide setup here (logging, analytics,
    // dependency configuration, appearance proxies, etc.).
    return YES;
}

#pragma mark - UISceneSession Lifecycle

- (UISceneConfiguration *)application:(UIApplication *)application
    configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession
                                   options:(UISceneConnectionOptions *)options {
    // The configuration name must match the entry declared in Info.plist's
    // UIApplicationSceneManifest. UIKit instantiates the SceneDelegate from it.
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration"
                                          sessionRole:connectingSceneSession.role];
}

- (void)application:(UIApplication *)application
    didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
    // TODO: Release any resources that were specific to the discarded scenes,
    // as they will not return.
}

@end
