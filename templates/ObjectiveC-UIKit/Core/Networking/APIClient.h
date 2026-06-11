//
//  APIClient.h
//  ObjectiveC-UIKit
//
//  Thin networking layer over NSURLSession. Exposes a shared singleton for
//  app code and an injectable initializer for tests.
//

#import <Foundation/Foundation.h>
#import "Item.h"

NS_ASSUME_NONNULL_BEGIN

/// Error domain for all errors produced by APIClient.
extern NSString *const APIClientErrorDomain;

/// Error codes within APIClientErrorDomain.
typedef NS_ENUM(NSInteger, APIClientErrorCode) {
    /// The constructed request URL was invalid.
    APIClientErrorCodeInvalidURL = 1,
    /// The transport layer returned an error (no usable response).
    APIClientErrorCodeTransport = 2,
    /// The HTTP status code indicated failure (>= 400).
    APIClientErrorCodeBadStatus = 3,
    /// The response body was empty when data was expected.
    APIClientErrorCodeEmptyResponse = 4,
    /// The response body could not be parsed as the expected JSON shape.
    APIClientErrorCodeDecoding = 5,
};

typedef void (^APIClientItemsCompletion)(NSArray<Item *> *_Nullable items,
                                         NSError *_Nullable error);

@interface APIClient : NSObject

/// Base URL all requests are resolved against.
@property (nonatomic, copy, readonly) NSURL *baseURL;

/// Shared instance for app code.
@property (class, nonatomic, readonly) APIClient *sharedClient;

/// Designated initializer. Inject a custom session (and base URL) in tests
/// to stub responses without hitting the network.
- (instancetype)initWithBaseURL:(NSURL *)baseURL
                        session:(NSURLSession *)session NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/// Fetches the list of items asynchronously. The completion block is always
/// invoked on the main queue with either `items` or `error` (never both).
- (void)fetchItemsWithCompletion:(APIClientItemsCompletion)completion;

@end

NS_ASSUME_NONNULL_END
