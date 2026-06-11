# Architecture — appcore (CPlusPlus-Framework)

`appcore` is a small **C++17** library scaffold designed to be built either as
a static library, or packaged as an Apple `.framework` / `xcframework` and
linked into an iOS/macOS app (typically through an Objective-C++ bridge — see
the `ObjectiveCpp-Mixed` template).

## Folder structure

```
CPlusPlus-Framework/
├── include/appcore/        Public API (the install surface)
│   ├── version.hpp         Version metadata
│   ├── result.hpp          Result<T,E> — error-as-value (header-only)
│   ├── event_bus.hpp       Type-erased pub/sub with RAII subscriptions
│   └── task_queue.hpp      Thread-safe FIFO queue (header-only template)
├── src/                    Private implementation (.cpp)
│   ├── version.cpp
│   └── event_bus.cpp
├── tests/                  Unit tests + a dependency-free harness
│   ├── test_appcore.hpp
│   ├── test_event_bus.cpp
│   └── test_result_queue.cpp
├── CMakeLists.txt          Primary build (lib + ctest), framework packaging notes
├── Makefile                Lightweight alternative build
└── docs/
```

**Why this shape?**

- **`include/appcore/` is the only public surface.** Headers are namespaced
  under `appcore/` so the library composes cleanly into a larger include path.
- **Header-only where it pays off.** `Result<T,E>` and `TaskQueue<T>` are
  templates and live entirely in headers; `EventBus` has a compiled `.cpp`
  because it carries state and a non-template implementation.
- **`namespace appcore`** keeps every symbol out of the global namespace —
  important when bridged into Objective-C++ alongside other C++ code.
- **No third-party deps.** Builds with any conforming C++17 compiler.

## Data flow

```
   producer threads                         consumer thread(s)
        │  queue.push(task)                       │
        ▼                                         ▼
   ┌─────────────────────────────┐   wait_pop()  drains FIFO,
   │     TaskQueue<T>  (mutex +   │ ◀──────────── returns nullopt
   │     condition_variable)      │               once closed+empty
   └─────────────────────────────┘

   EventBus.subscribe(topic, fn) ─▶ Subscription (RAII token)
   EventBus.publish(topic, data) ─▶ snapshot handlers, invoke outside lock

   work() ─▶ Result<T,Error>  ──▶  is_ok() ? value() : error()
```

## Design patterns / idioms

- **Error-as-value** (`Result<T,E>`) instead of exceptions for predictable,
  ABI-friendly control flow — mirrors Swift `Result`.
- **RAII ownership** — `EventBus::Subscription` unsubscribes in its destructor;
  move-only, non-copyable.
- **Producer/consumer** with `std::condition_variable` and explicit `close()`
  for deterministic shutdown.
- **Pimpl-friendly, namespaced, no global state** — safe to embed in a larger
  app and to expose across an Objective-C++ bridge.
- **Snapshot-then-invoke** in `EventBus::publish` so a handler may subscribe or
  unsubscribe during delivery without deadlocking.

## Where to add a new feature

1. Add `include/appcore/<feature>.hpp` (header-only) or a header + matching
   `src/<feature>.cpp`.
2. If it has a `.cpp`, add it to the `add_library(appcore …)` sources in
   `CMakeLists.txt` (the `Makefile` globs `src/*.cpp` automatically).
3. Add `tests/test_<feature>.cpp` and register it in the `foreach` loop in
   `CMakeLists.txt` (the `Makefile` globs `tests/test_*.cpp` automatically).
4. `make test` or `ctest --test-dir build --output-on-failure`.
