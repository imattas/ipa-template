# Setup — appcore (CPlusPlus-Framework)

## Prerequisites

- A C++17 compiler: `clang++` (Xcode / Command Line Tools) or `g++`.
- One of: **CMake ≥ 3.20** (recommended) or **make** + `ar`.
- A threads implementation (pthreads on Apple platforms — linked
  automatically). No third-party dependencies.

On macOS:

```sh
xcode-select --install      # clang++, make, ar
brew install cmake          # optional, for the CMake build
```

## Build & test with CMake (recommended)

```sh
cd templates/CPlusPlus-Framework
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
ctest --test-dir build --output-on-failure
```

## Build & test with make

```sh
cd templates/CPlusPlus-Framework
make            # build/libappcore.a
make test       # build + run all unit tests
```

Add sanitizers while developing:

```sh
make CXXFLAGS_EXTRA="-fsanitize=address,undefined" test
```

## Packaging as an Apple framework

`CMakeLists.txt` contains a commented block that flips the target to a real
macOS/iOS `.framework` (`FRAMEWORK TRUE`, bundle identifier, public headers).
For multi-platform distribution, build per-SDK and combine with:

```sh
xcodebuild -create-xcframework -framework <ios>/appcore.framework \
    -framework <macos>/appcore.framework -output appcore.xcframework
```

To consume the C++ API from Swift, wrap it in an Objective-C++ bridge — see the
`ObjectiveCpp-Mixed` template for the pattern (keep bridge headers C++-free).

## Continuous integration

The repository's GitHub Actions workflow builds this template on
`macos-latest` and runs the unit tests. See the root
[`docs/CI.md`](../../../docs/CI.md).
