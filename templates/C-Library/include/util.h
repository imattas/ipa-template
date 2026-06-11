/*
 * util.h — umbrella header for libutil.
 *
 * Include this single header to pull in the whole public API.
 *
 *   #include "util.h"
 *
 * libutil is a small, dependency-free, C11 utility library intended as a
 * starting point for low-level C targets (static/dynamic library, or an
 * embedded helper inside a larger Apple-platform app).
 */
#ifndef UTIL_H
#define UTIL_H

#define UTIL_VERSION_MAJOR 0
#define UTIL_VERSION_MINOR 1
#define UTIL_VERSION_PATCH 0
#define UTIL_VERSION_STRING "0.1.0"

#include "util/status.h"
#include "util/dyn_array.h"
#include "util/str_util.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Returns the compiled library version string, e.g. "0.1.0". */
const char *util_version(void);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* UTIL_H */
