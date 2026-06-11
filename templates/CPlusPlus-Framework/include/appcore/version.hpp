// version.hpp — library version metadata for appcore.
#pragma once

#include <string_view>

namespace appcore {

inline constexpr int kVersionMajor = 0;
inline constexpr int kVersionMinor = 1;
inline constexpr int kVersionPatch = 0;

// Returns the semantic version string, e.g. "0.1.0".
std::string_view version() noexcept;

}  // namespace appcore
