/*
 * str_util.h — small heap-backed string builder and helpers.
 *
 * util_str is a growable, always-NUL-terminated string buffer. It is handy
 * for assembling output without manual realloc bookkeeping.
 */
#ifndef UTIL_STR_UTIL_H
#define UTIL_STR_UTIL_H

#include <stddef.h>
#include "util/status.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    char  *data;     /* NUL-terminated buffer (NULL until first append) */
    size_t length;   /* strlen(data), excluding the terminator          */
    size_t capacity; /* allocated bytes, including the terminator        */
} util_str;

/* Initialize an empty string builder. Never fails. */
void util_str_init(util_str *s);

/* Append a C string. Returns UTIL_ERR_NOMEM on growth failure. */
util_status util_str_append(util_str *s, const char *cstr);

/* Append `len` bytes (may contain no embedded NULs for sane results). */
util_status util_str_append_n(util_str *s, const char *bytes, size_t len);

/* Append a single character. */
util_status util_str_append_char(util_str *s, char c);

/* Borrow the current contents (valid until the next mutation). */
const char *util_str_cstr(const util_str *s);

/* Reset length to 0 but keep the allocation. */
void util_str_clear(util_str *s);

/* Free the buffer and reset to the empty state. */
void util_str_destroy(util_str *s);

/*
 * Free-standing helpers (do not require a util_str).
 * Caller owns the returned heap string and must free() it; NULL on OOM.
 */
char *util_strdup(const char *cstr);

/* Trim leading/trailing ASCII whitespace in place, returns `s`. */
char *util_str_trim(char *s);

/* 1 if `s` ends with `suffix`, else 0. */
int util_str_ends_with(const char *s, const char *suffix);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* UTIL_STR_UTIL_H */
