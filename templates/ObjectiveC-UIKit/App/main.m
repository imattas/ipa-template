//
//  main.m
//  ObjectiveC-UIKit
//
//  Standard UIKit entry point.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

int main(int argc, char *argv[]) {
    @autoreleasepool {
        // Pass nil for the principal class to use the default UIApplication,
        // and the AppDelegate class name as the delegate.
        return UIApplicationMain(argc,
                                 argv,
                                 nil,
                                 NSStringFromClass([AppDelegate class]));
    }
}
