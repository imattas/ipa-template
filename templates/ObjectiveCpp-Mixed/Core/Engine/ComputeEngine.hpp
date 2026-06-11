#pragma once

#include <vector>
#include <cstddef>

namespace app {

// ComputeEngine is a pure C++ statistics processor.
//
// It maintains a running collection of double samples and computes
// summary statistics (mean, population standard deviation) on demand.
//
// This class is intentionally free of any Objective-C or platform code so
// that it can be unit-tested and reused on any C++17 toolchain. The bridge
// layer (EngineBridge) is responsible for exposing it to Objective-C/Swift.
class ComputeEngine {
public:
    ComputeEngine() = default;
    ~ComputeEngine() = default;

    // ComputeEngine owns its sample buffer (RAII via std::vector). Copying is
    // allowed and produces an independent copy of the samples.
    ComputeEngine(const ComputeEngine&) = default;
    ComputeEngine& operator=(const ComputeEngine&) = default;
    ComputeEngine(ComputeEngine&&) noexcept = default;
    ComputeEngine& operator=(ComputeEngine&&) noexcept = default;

    // Appends a single sample to the dataset.
    void addSample(double value);

    // Returns the arithmetic mean of all samples, or 0.0 if there are none.
    double mean() const;

    // Returns the population standard deviation, or 0.0 if there are
    // fewer than two samples.
    double standardDeviation() const;

    // Returns the smallest observed sample, or 0.0 if there are none.
    double minimum() const;

    // Returns the largest observed sample, or 0.0 if there are none.
    double maximum() const;

    // Number of samples currently stored.
    std::size_t count() const noexcept;

    // Clears all samples, restoring the engine to its initial state.
    void reset() noexcept;

private:
    std::vector<double> samples_;
};

} // namespace app
