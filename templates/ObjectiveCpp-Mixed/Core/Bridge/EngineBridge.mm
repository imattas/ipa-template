#import "EngineBridge.h"

// This translation unit is Objective-C++ (.mm), so it may freely #include the
// pure C++ engine and use STL types. None of this is visible from the header.
#include "ComputeEngine.hpp"

#include <memory>

@implementation EngineBridge {
    // Pimpl: the C++ engine is owned via a unique_ptr ivar. ARC manages the
    // Objective-C object; the unique_ptr's destructor (invoked when the
    // EngineBridge instance is deallocated) tears down the C++ object. This is
    // the clean memory-management story for mixing ARC with C++ RAII members.
    std::unique_ptr<app::ComputeEngine> _engine;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _engine = std::make_unique<app::ComputeEngine>();
    }
    return self;
}

- (void)addSample:(double)value {
    _engine->addSample(value);
}

- (double)mean {
    return _engine->mean();
}

- (double)standardDeviation {
    return _engine->standardDeviation();
}

- (double)minimum {
    return _engine->minimum();
}

- (double)maximum {
    return _engine->maximum();
}

- (NSUInteger)count {
    return static_cast<NSUInteger>(_engine->count());
}

- (void)reset {
    _engine->reset();
}

// NOTE: No explicit -dealloc needed. When the EngineBridge is deallocated, the
// _engine unique_ptr ivar is destroyed automatically, freeing the C++ object.

@end
