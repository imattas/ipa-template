#import "AppDelegate.h"

// Compiled as Objective-C++ (.mm). Mostly plain ObjC, but using .mm means we
// could pull in C++ headers here too if app-wide bootstrap needed the engine.

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions {
    // TODO: Perform any application-wide setup here (logging, analytics, etc.).
    return YES;
}

#pragma mark - UISceneSession Lifecycle

- (UISceneConfiguration *)application:(UIApplication *)application
    configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession
                                   options:(UISceneConnectionOptions *)options {
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration"
                                          sessionRole:connectingSceneSession.role];
}

- (void)application:(UIApplication *)application
    didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
    // TODO: Release resources tied to discarded scenes.
}

@end
