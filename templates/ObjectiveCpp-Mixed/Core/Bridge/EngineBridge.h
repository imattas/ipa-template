#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// EngineBridge is a pure Objective-C facade over the C++ `app::ComputeEngine`.
///
/// IMPORTANT: This header contains NO C++ types. That is what keeps it
/// importable from both Objective-C and Swift. The C++ engine is held behind
/// an opaque pointer (Pimpl idiom) whose concrete type is only known inside
/// the `EngineBridge.mm` translation unit, which is compiled as Objective-C++.
///
/// Consumers add samples and read back summary statistics. All numeric values
/// are plain `double`s so no C++ leaks across the boundary.
@interface EngineBridge : NSObject

/// Appends a single sample to the underlying engine.
- (void)addSample:(double)value;

/// Arithmetic mean of all samples, or 0.0 when empty.
- (double)mean;

/// Population standard deviation, or 0.0 when fewer than two samples.
- (double)standardDeviation;

/// Smallest observed sample, or 0.0 when empty.
- (double)minimum;

/// Largest observed sample, or 0.0 when empty.
- (double)maximum;

/// Number of samples currently stored.
- (NSUInteger)count;

/// Clears all samples.
- (void)reset;

@end

NS_ASSUME_NONNULL_END
