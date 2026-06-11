# C-Library Template — `libutil`

![CI](https://github.com/imattas/ipa-template/actions/workflows/build.yml/badge.svg)

A small, dependency-free **C11** utility library set up as production-ready
scaffolding for a low-level C target: clean public-header / private-source
split, allocation-failure-aware API, a `Makefile`, and a zero-dependency unit
test harness. Use it as the starting point for a static library, a vendored
helper inside an iOS/macOS app, or the C core of an `xcframework`.

## What's inside

- **`util_dyn_array`** — a generic, type-erased growable array (vector) with
  geometric growth, optional element destructor, and overflow-checked sizing.
- **`util_str`** — a heap-backed, always-NUL-terminated string builder plus
  free-standing helpers (`util_strdup`, `util_str_trim`, `util_str_ends_with`).
- **`util_status`** — shared status codes with `util_status_str()`.

Every operation that can allocate returns a `util_status`, so OOM is handled
explicitly rather than by crashing.

## Folder structure

```
C-Library/
├── include/
│   ├── util.h                 Umbrella header + version macros
│   └── util/
│       ├── status.h
│       ├── dyn_array.h
│       └── str_util.h
├── src/
│   ├── status.c
│   ├── version.c
│   ├── dyn_array.c
│   └── str_util.c
├── tests/
│   ├── test_util.h            Tiny dependency-free harness
│   ├── test_dyn_array.c
│   └── test_str_util.c
├── Makefile
├── docs/
│   ├── ARCHITECTURE.md
│   └── SETUP.md
└── README.md
```

## Quick start

```sh
cd templates/C-Library
make            # build build/libutil.a
make test       # build + run unit tests
```

```c
#include "util.h"

util_dyn_array nums;
util_dyn_array_init(&nums, sizeof(int), NULL);
for (int i = 0; i < 10; ++i) util_dyn_array_push(&nums, &i);
printf("%zu items, libutil %s\n", util_dyn_array_count(&nums), util_version());
util_dyn_array_destroy(&nums);
```

## Pattern

Public/private header split, status-returning (error-as-value) API, and
RAII-style ownership via optional element destructors. See
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) and
[`docs/SETUP.md`](docs/SETUP.md).
