# CPlusPlus-Framework Template — `appcore`

![CI](https://github.com/imattas/ipa-template/actions/workflows/build.yml/badge.svg)

A small, dependency-free **C++17** library scaffold, ready to grow into a real
static library or an Apple `.framework` / `xcframework`. It demonstrates the
patterns you actually want in a shared C++ core: error-as-value, RAII
ownership, thread-safe coordination, and a clean public/private split — all
under a single `appcore` namespace so it bridges safely into Objective-C++.

## What's inside

- **`Result<T, E>`** — header-only error-as-value type with `map` / `value_or`
  (Swift-`Result`-style), built on `std::variant`.
- **`EventBus`** — type-erased publish/subscribe with **RAII subscription
  tokens** that auto-unsubscribe; thread-safe, deadlock-safe delivery.
- **`TaskQueue<T>`** — thread-safe FIFO with blocking `wait_pop`, non-blocking
  `try_pop`, and clean `close()` shutdown — the core of a worker pool.
- **`version()`** — library version metadata.

## Folder structure

```
CPlusPlus-Framework/
├── include/appcore/
│   ├── version.hpp
│   ├── result.hpp
│   ├── event_bus.hpp
│   └── task_queue.hpp
├── src/
│   ├── version.cpp
│   └── event_bus.cpp
├── tests/
│   ├── test_appcore.hpp        Dependency-free harness
│   ├── test_event_bus.cpp
│   └── test_result_queue.cpp
├── CMakeLists.txt
├── Makefile
├── docs/
│   ├── ARCHITECTURE.md
│   └── SETUP.md
└── README.md
```

## Quick start

```sh
cd templates/CPlusPlus-Framework

# CMake (recommended)
cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build
ctest --test-dir build --output-on-failure

# …or make
make test
```

```cpp
#include "appcore/event_bus.hpp"

appcore::EventBus bus;
auto sub = bus.subscribe("login", [](const std::string& user) {
    std::printf("welcome %s\n", user.c_str());
});
bus.publish("login", "ada");   // prints: welcome ada
```

## Pattern

Public/private header split, error-as-value (`Result`), RAII ownership, and
producer/consumer concurrency — namespaced for clean Objective-C++ bridging.
See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) and
[`docs/SETUP.md`](docs/SETUP.md).
