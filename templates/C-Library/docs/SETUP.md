# Setup — libutil (C-Library)

## Prerequisites

- A C11-capable compiler: `clang` (ships with Xcode / Command Line Tools) or
  `gcc`.
- `make` and `ar` (both included with the Xcode Command Line Tools).
- No third-party dependencies.

On macOS, install the toolchain with:

```sh
xcode-select --install
```

## Build

```sh
cd templates/C-Library
make            # produces build/libutil.a
```

Pick a specific compiler or add sanitizers:

```sh
make CC=clang
make CFLAGS_EXTRA="-fsanitize=address,undefined" test
```

## Run the tests

```sh
make test
```

Expected output ends with `0 failed` for each test binary. The test harness
(`tests/test_util.h`) is intentionally dependency-free so the library builds
on any toolchain without installing a test framework.

## Using it in an Xcode / Apple target

- Add `include/` to **Header Search Paths**.
- Either link `build/libutil.a`, or add `src/*.c` directly to your target's
  **Compile Sources**.
- `#include "util.h"` and you have the whole API.

## Continuous integration

The repository's GitHub Actions workflow builds this template on
`macos-latest` with `make` and runs `make test`. See the root
[`docs/CI.md`](../../../docs/CI.md).
