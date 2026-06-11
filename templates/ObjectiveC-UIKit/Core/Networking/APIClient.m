//
//  APIClient.m
//  ObjectiveC-UIKit
//

#import "APIClient.h"

NSString *const APIClientErrorDomain = @"com.example.objcuikit.APIClientErrorDomain";

// TODO: Point this at your real backend, or load it from a build configuration.
static NSString *const kDefaultBaseURLString = @"https://api.example.com";
static NSString *const kItemsPath = @"/v1/items";

@interface APIClient ()
@property (nonatomic, strong, readonly) NSURLSession *session;
@end

@implementation APIClient

#pragma mark - Lifecycle

+ (APIClient *)sharedClient {
    static APIClient *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURL *baseURL = [NSURL URLWithString:kDefaultBaseURLString];
        NSURLSession *session =
            [NSURLSession sessionWithConfiguration:
                [NSURLSessionConfiguration defaultSessionConfiguration]];
        shared = [[APIClient alloc] initWithBaseURL:baseURL session:session];
    });
    return shared;
}

- (instancetype)initWithBaseURL:(NSURL *)baseURL
                        session:(NSURLSession *)session {
    NSParameterAssert(baseURL);
    NSParameterAssert(session);
    self = [super init];
    if (self) {
        _baseURL = [baseURL copy];
        _session = session;
    }
    return self;
}

#pragma mark - Requests

- (void)fetchItemsWithCompletion:(APIClientItemsCompletion)completion {
    NSParameterAssert(completion);

    NSURL *url = [NSURL URLWithString:kItemsPath relativeToURL:self.baseURL];
    if (url == nil) {
        NSError *error =
            [self errorWithCode:APIClientErrorCodeInvalidURL
                    description:@"Could not construct a valid items URL."];
        [self deliver:completion items:nil error:error];
        return;
    }

    NSURLSessionDataTask *task =
        [self.session dataTaskWithURL:url
                    completionHandler:^(NSData *_Nullable data,
                                        NSURLResponse *_Nullable response,
                                        NSError *_Nullable transportError) {
        if (transportError != nil) {
            NSError *wrapped =
                [self errorWithCode:APIClientErrorCodeTransport
                        description:transportError.localizedDescription
                    underlyingError:transportError];
            [self deliver:completion items:nil error:wrapped];
            return;
        }

        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSInteger status = ((NSHTTPURLResponse *)response).statusCode;
            if (status >= 400) {
                NSString *desc =
                    [NSString stringWithFormat:@"Server returned HTTP %ld.",
                     (long)status];
                NSError *error = [self errorWithCode:APIClientErrorCodeBadStatus
                                         description:desc];
                [self deliver:completion items:nil error:error];
                return;
            }
        }

        if (data.length == 0) {
            NSError *error =
                [self errorWithCode:APIClientErrorCodeEmptyResponse
                        description:@"The server returned an empty response."];
            [self deliver:completion items:nil error:error];
            return;
        }

        NSError *jsonError = nil;
        id json = [NSJSONSerialization JSONObjectWithData:data
                                                  options:0
                                                    error:&jsonError];
        if (json == nil || ![json isKindOfClass:[NSArray class]]) {
            NSError *error =
                [self errorWithCode:APIClientErrorCodeDecoding
                        description:@"Response was not a JSON array of items."
                    underlyingError:jsonError];
            [self deliver:completion items:nil error:error];
            return;
        }

        NSMutableArray<Item *> *items = [NSMutableArray array];
        for (id element in (NSArray *)json) {
            if (![element isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            Item *item = [Item itemFromJSON:element];
            if (item != nil) {
                [items addObject:item];
            }
        }

        [self deliver:completion items:[items copy] error:nil];
    }];

    [task resume];
}

#pragma mark - Helpers

/// Always hop back to the main queue before invoking UI-facing completions.
- (void)deliver:(APIClientItemsCompletion)completion
          items:(nullable NSArray<Item *> *)items
          error:(nullable NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(items, error);
    });
}

- (NSError *)errorWithCode:(APIClientErrorCode)code
               description:(NSString *)description {
    return [self errorWithCode:code
                   description:description
               underlyingError:nil];
}

- (NSError *)errorWithCode:(APIClientErrorCode)code
               description:(NSString *)description
           underlyingError:(nullable NSError *)underlying {
    NSMutableDictionary<NSErrorUserInfoKey, id> *userInfo = [NSMutableDictionary dictionary];
    userInfo[NSLocalizedDescriptionKey] = description;
    if (underlying != nil) {
        userInfo[NSUnderlyingErrorKey] = underlying;
    }
    return [NSError errorWithDomain:APIClientErrorDomain
                              code:code
                          userInfo:userInfo];
}

@end
