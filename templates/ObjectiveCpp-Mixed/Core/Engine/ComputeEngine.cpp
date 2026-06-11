#include "ComputeEngine.hpp"

#include <algorithm>
#include <cmath>
#include <numeric>

namespace app {

void ComputeEngine::addSample(double value) {
    samples_.push_back(value);
}

double ComputeEngine::mean() const {
    if (samples_.empty()) {
        return 0.0;
    }
    const double sum = std::accumulate(samples_.begin(), samples_.end(), 0.0);
    return sum / static_cast<double>(samples_.size());
}

double ComputeEngine::standardDeviation() const {
    if (samples_.size() < 2) {
        return 0.0;
    }
    const double mu = mean();
    const double accumulated = std::accumulate(
        samples_.begin(), samples_.end(), 0.0,
        [mu](double acc, double sample) {
            const double diff = sample - mu;
            return acc + diff * diff;
        });
    // Population standard deviation (divide by N).
    return std::sqrt(accumulated / static_cast<double>(samples_.size()));
}

double ComputeEngine::minimum() const {
    if (samples_.empty()) {
        return 0.0;
    }
    return *std::min_element(samples_.begin(), samples_.end());
}

double ComputeEngine::maximum() const {
    if (samples_.empty()) {
        return 0.0;
    }
    return *std::max_element(samples_.begin(), samples_.end());
}

std::size_t ComputeEngine::count() const noexcept {
    return samples_.size();
}

void ComputeEngine::reset() noexcept {
    samples_.clear();
}

} // namespace app
