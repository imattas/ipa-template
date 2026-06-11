#import "APIClient.h"

NSErrorDomain const APIClientErrorDomain = @"com.example.objcppmixed.APIClientErrorDomain";

@interface APIClient ()
@property(nonatomic, strong, readonly) NSURLSession *session;
@end

@implementation APIClient

- (instancetype)init {
    return [self initWithSession:NSURLSession.sharedSession];
}

- (instancetype)initWithSession:(NSURLSession *)session {
    NSParameterAssert(session != nil);
    self = [super init];
    if (self) {
        _session = session;
    }
    return self;
}

- (void)fetchJSONFromURL:(NSURL *)url
              completion:(void (^)(id _Nullable, NSError *_Nullable))completion {
    if (url == nil) {
        completion(nil, [self errorWithCode:APIClientErrorCodeInvalidURL
                                description:@"A nil or invalid URL was provided."
                            underlyingError:nil]);
        return;
    }

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [self.session
        dataTaskWithURL:url
      completionHandler:^(NSData *_Nullable data,
                          NSURLResponse *_Nullable response,
                          NSError *_Nullable error) {
          typeof(self) strongSelf = weakSelf;
          if (strongSelf == nil) {
              return;
          }

          if (error != nil) {
              completion(nil, [strongSelf errorWithCode:APIClientErrorCodeTransport
                                            description:@"The network request failed."
                                        underlyingError:error]);
              return;
          }

          if ([response isKindOfClass:NSHTTPURLResponse.class]) {
              const NSInteger status = ((NSHTTPURLResponse *)response).statusCode;
              if (status < 200 || status >= 300) {
                  NSString *desc = [NSString stringWithFormat:
                                    @"Server returned HTTP status %ld.", (long)status];
                  completion(nil, [strongSelf errorWithCode:APIClientErrorCodeBadStatus
                                                description:desc
                                            underlyingError:nil]);
                  return;
              }
          }

          if (data == nil || data.length == 0) {
              completion(nil, [strongSelf errorWithCode:APIClientErrorCodeEmptyResponse
                                            description:@"The response body was empty."
                                        underlyingError:nil]);
              return;
          }

          NSError *jsonError = nil;
          id object = [NSJSONSerialization JSONObjectWithData:data
                                                      options:0
                                                        error:&jsonError];
          if (object == nil) {
              completion(nil, [strongSelf errorWithCode:APIClientErrorCodeDecoding
                                            description:@"Failed to decode the JSON response."
                                        underlyingError:jsonError]);
              return;
          }

          completion(object, nil);
      }];

    // TODO: Consider exposing the data task so callers can cancel in-flight requests.
    [task resume];
}

#pragma mark - Helpers

- (NSError *)errorWithCode:(APIClientErrorCode)code
               description:(NSString *)description
           underlyingError:(nullable NSError *)underlying {
    NSMutableDictionary<NSErrorUserInfoKey, id> *userInfo = [NSMutableDictionary dictionary];
    userInfo[NSLocalizedDescriptionKey] = description;
    if (underlying != nil) {
        userInfo[NSUnderlyingErrorKey] = underlying;
    }
    return [NSError errorWithDomain:APIClientErrorDomain code:code userInfo:userInfo];
}

@end
