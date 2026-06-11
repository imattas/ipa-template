//
//  APIClientTests.m
//  ObjectiveC-UIKitTests
//
//  Self-contained unit tests for APIClient. A stub NSURLProtocol intercepts
//  requests so the network is never touched.
//

#import <XCTest/XCTest.h>
#import "APIClient.h"
#import "Item.h"

#pragma mark - Stub URL Protocol

/// Intercepts every request and replies with class-level canned data/response/error.
@interface StubURLProtocol : NSURLProtocol
@property (class, nonatomic, copy, nullable) NSData *stubData;
@property (class, nonatomic, copy, nullable) NSError *stubError;
@property (class, nonatomic, assign) NSInteger stubStatusCode;
+ (void)reset;
@end

@implementation StubURLProtocol

static NSData *sStubData = nil;
static NSError *sStubError = nil;
static NSInteger sStubStatusCode = 200;

+ (NSData *)stubData { return sStubData; }
+ (void)setStubData:(NSData *)stubData { sStubData = [stubData copy]; }
+ (NSError *)stubError { return sStubError; }
+ (void)setStubError:(NSError *)stubError { sStubError = [stubError copy]; }
+ (NSInteger)stubStatusCode { return sStubStatusCode; }
+ (void)setStubStatusCode:(NSInteger)code { sStubStatusCode = code; }

+ (void)reset {
    sStubData = nil;
    sStubError = nil;
    sStubStatusCode = 200;
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request { return YES; }
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request { return request; }

- (void)startLoading {
    if (StubURLProtocol.stubError != nil) {
        [self.client URLProtocol:self didFailWithError:StubURLProtocol.stubError];
        return;
    }

    NSHTTPURLResponse *response =
        [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
                                    statusCode:StubURLProtocol.stubStatusCode
                                   HTTPVersion:@"HTTP/1.1"
                                  headerFields:nil];
    [self.client URLProtocol:self
          didReceiveResponse:response
          cacheStoragePolicy:NSURLCacheStorageNotAllowed];

    if (StubURLProtocol.stubData != nil) {
        [self.client URLProtocol:self didLoadData:StubURLProtocol.stubData];
    }
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading {}

@end

#pragma mark - Tests

@interface APIClientTests : XCTestCase
@property (nonatomic, strong) APIClient *client;
@end

@implementation APIClientTests

- (void)setUp {
    [super setUp];
    [StubURLProtocol reset];

    NSURLSessionConfiguration *config =
        [NSURLSessionConfiguration ephemeralSessionConfiguration];
    config.protocolClasses = @[ [StubURLProtocol class] ];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

    NSURL *baseURL = [NSURL URLWithString:@"https://api.test.local"];
    self.client = [[APIClient alloc] initWithBaseURL:baseURL session:session];
}

- (void)tearDown {
    [StubURLProtocol reset];
    self.client = nil;
    [super tearDown];
}

/// The error domain constant must be exactly as declared so callers can match it.
- (void)testErrorDomainConstant {
    XCTAssertEqualObjects(APIClientErrorDomain,
                          @"com.example.objcuikit.APIClientErrorDomain");
}

/// A transport-layer failure should surface as an APIClient transport error.
- (void)testTransportErrorIsWrapped {
    NSError *underlying = [NSError errorWithDomain:NSURLErrorDomain
                                              code:NSURLErrorNotConnectedToInternet
                                          userInfo:nil];
    StubURLProtocol.stubError = underlying;

    XCTestExpectation *expectation =
        [self expectationWithDescription:@"completion called"];
    [self.client fetchItemsWithCompletion:^(NSArray<Item *> *_Nullable items,
                                            NSError *_Nullable error) {
        XCTAssertNil(items);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, APIClientErrorDomain);
        XCTAssertEqual(error.code, APIClientErrorCodeTransport);
        XCTAssertTrue([NSThread isMainThread],
                      @"Completion must be delivered on the main queue.");
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

/// A valid JSON array should decode into Item models, skipping malformed entries.
- (void)testValidJSONDecodesItems {
    NSArray *payload = @[
        @{ @"id": @"1", @"title": @"First", @"subtitle": @"Sub" },
        @{ @"id": @2, @"title": @"Second" },
        @{ @"title": @"Missing id - should be skipped" },
    ];
    StubURLProtocol.stubData = [NSJSONSerialization dataWithJSONObject:payload
                                                              options:0
                                                                error:nil];
    StubURLProtocol.stubStatusCode = 200;

    XCTestExpectation *expectation =
        [self expectationWithDescription:@"completion called"];
    [self.client fetchItemsWithCompletion:^(NSArray<Item *> *_Nullable items,
                                            NSError *_Nullable error) {
        XCTAssertNil(error);
        XCTAssertNotNil(items);
        XCTAssertEqual(items.count, 2u);
        XCTAssertEqualObjects(items.firstObject.title, @"First");
        XCTAssertEqualObjects(items.firstObject.identifier, @"1");
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

/// An HTTP status >= 400 should produce a bad-status error.
- (void)testBadStatusCodeProducesError {
    StubURLProtocol.stubData = [@"{}" dataUsingEncoding:NSUTF8StringEncoding];
    StubURLProtocol.stubStatusCode = 500;

    XCTestExpectation *expectation =
        [self expectationWithDescription:@"completion called"];
    [self.client fetchItemsWithCompletion:^(NSArray<Item *> *_Nullable items,
                                            NSError *_Nullable error) {
        XCTAssertNil(items);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, APIClientErrorDomain);
        XCTAssertEqual(error.code, APIClientErrorCodeBadStatus);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

@end
