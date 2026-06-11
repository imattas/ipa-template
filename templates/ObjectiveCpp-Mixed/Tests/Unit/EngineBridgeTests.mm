#import <XCTest/XCTest.h>

// The test target is compiled as Objective-C++, so we can import both the pure
// ObjC bridge and the underlying C++ engine directly and cross-check them.
#import "EngineBridge.h"
#include "ComputeEngine.hpp"

#include <cmath>

@interface EngineBridgeTests : XCTestCase
@end

@implementation EngineBridgeTests {
    EngineBridge *_bridge;
}

- (void)setUp {
    [super setUp];
    _bridge = [[EngineBridge alloc] init];
}

- (void)tearDown {
    _bridge = nil;
    [super tearDown];
}

- (void)testMeanOfKnownSamples {
    for (double value : {2.0, 4.0, 6.0, 8.0}) {
        [_bridge addSample:value];
    }
    XCTAssertEqual([_bridge count], 4u);
    XCTAssertEqualWithAccuracy([_bridge mean], 5.0, 1e-9,
                               @"Mean of {2,4,6,8} should be 5.0");
}

- (void)testStandardDeviationMatchesCppEngine {
    const double samples[] = {2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0};
    const size_t n = sizeof(samples) / sizeof(samples[0]);

    app::ComputeEngine reference;
    for (size_t i = 0; i < n; ++i) {
        [_bridge addSample:samples[i]];
        reference.addSample(samples[i]);
    }

    // Population standard deviation of this classic dataset is 2.0.
    XCTAssertEqualWithAccuracy([_bridge standardDeviation], 2.0, 1e-9);
    // And the bridge must agree with the raw C++ engine it wraps.
    XCTAssertEqualWithAccuracy([_bridge standardDeviation],
                               reference.standardDeviation(), 1e-12,
                               @"Bridge must forward faithfully to the C++ engine");
}

- (void)testResetClearsState {
    [_bridge addSample:10.0];
    [_bridge addSample:20.0];
    XCTAssertEqual([_bridge count], 2u);

    [_bridge reset];

    XCTAssertEqual([_bridge count], 0u);
    XCTAssertEqualWithAccuracy([_bridge mean], 0.0, 1e-12);
    XCTAssertEqualWithAccuracy([_bridge standardDeviation], 0.0, 1e-12);
}

- (void)testMinimumAndMaximum {
    for (double value : {3.0, -1.0, 7.5, 0.0}) {
        [_bridge addSample:value];
    }
    XCTAssertEqualWithAccuracy([_bridge minimum], -1.0, 1e-12);
    XCTAssertEqualWithAccuracy([_bridge maximum], 7.5, 1e-12);
}

@end
