# Architecture — libutil (C-Library)

`libutil` is a small, dependency-free C11 utility library. It is structured as
a classic public-header / private-implementation split so it can be consumed
either as a standalone static library or vendored directly into a larger
Apple-platform target (e.g. compiled into an app or an `xcframework`).

## Folder structure

```
C-Library/
├── include/              Public API — the only headers consumers include
│   ├── util.h            Umbrella header (+ version macros)
│   └── util/
│       ├── status.h      Shared status / error codes
│       ├── dyn_array.h   Generic growable array
│       └── str_util.h    String builder + helpers
├── src/                  Private implementation (.c) — never installed
│   ├── status.c
│   ├── version.c
│   ├── dyn_array.c
│   └── str_util.c
├── tests/                Unit tests + a tiny zero-dependency harness
│   ├── test_util.h
│   ├── test_dyn_array.c
│   └── test_str_util.c
├── Makefile              Build the static lib + run tests
└── docs/
```

**Why this shape?**

- **`include/` is the contract.** Everything a consumer needs is here and
  nothing else. Internal helpers live as `static` functions inside `src/`.
- **Header namespacing (`util/…`).** Avoids collisions when the library is
  dropped into a bigger include path.
- **Status-returning API.** Every operation that can allocate returns a
  `util_status` instead of crashing, so the library is usable in contexts
  where allocation failure must be handled (the same discipline you want in a
  low-level Apple target).

## Data flow

```
   caller code
       │  util_dyn_array_push(&arr, &elem)
       ▼
 ┌───────────────┐   grows geometrically    ┌──────────────┐
 │ util_dyn_array │ ───────────────────────▶ │  realloc()   │
 │  (count/cap)   │ ◀─────────────────────── │  heap buffer │
 └───────────────┘   returns util_status     └──────────────┘
       │
       │ util_status_str(rc)  ──▶ "out of memory" / "ok" / …
       ▼
   error handling
```

## Design patterns / idioms

- **Opaque-ish structs with documented fields** — callers may read fields but
  mutate only through functions.
- **Geometric growth** (doubling) for amortized O(1) append.
- **Overflow-checked sizing** before every `realloc`.
- **Optional element destructor** (`util_elem_dtor`) so the array can own
  heap-allocated elements (RAII-like cleanup on `destroy`/`pop`/`clear`).
- **Single umbrella header** (`util.h`) for convenience, with granular
  headers for callers who want to include only what they use.

## Where to add a new feature

1. Add the public declarations in a new `include/util/<feature>.h` and include
   it from `include/util.h`.
2. Implement in `src/<feature>.c`; keep internals `static`.
3. Add `tests/test_<feature>.c` (the `Makefile` globs `tests/test_*.c`
   automatically — no Makefile edit needed).
4. Run `make test`.
