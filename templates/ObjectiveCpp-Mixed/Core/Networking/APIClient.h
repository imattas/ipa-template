#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Error domain for all errors surfaced by `APIClient`.
extern NSErrorDomain const APIClientErrorDomain;

/// Error codes reported in the `APIClientErrorDomain`.
typedef NS_ENUM(NSInteger, APIClientErrorCode) {
    APIClientErrorCodeInvalidURL = 1,
    APIClientErrorCodeTransport = 2,
    APIClientErrorCodeBadStatus = 3,
    APIClientErrorCodeEmptyResponse = 4,
    APIClientErrorCodeDecoding = 5,
};

/// A minimal JSON-fetching networking client built on NSURLSession.
///
/// This is a plain Objective-C interface that can live happily next to the C++
/// engine in the same app. The implementation is `.mm` purely so it could call
/// into C++ if desired; the public surface stays C++-free.
@interface APIClient : NSObject

/// Creates a client backed by `NSURLSession.sharedSession`.
- (instancetype)init;

/// Creates a client backed by a custom session (useful for tests).
- (instancetype)initWithSession:(NSURLSession *)session NS_DESIGNATED_INITIALIZER;

/// Fetches the resource at `url` and parses the response body as JSON.
///
/// The completion handler is always invoked exactly once, on an arbitrary
/// queue. On success `object` is the decoded JSON and `error` is nil; on
/// failure `object` is nil and `error` describes the problem.
- (void)fetchJSONFromURL:(NSURL *)url
              completion:(void (^)(id _Nullable object, NSError *_Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
