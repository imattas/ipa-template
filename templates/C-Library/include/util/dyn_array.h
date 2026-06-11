/*
 * dyn_array.h — generic, type-erased dynamic array (growable vector).
 *
 * Part of libutil, a small portable C utility library.
 *
 * The container stores fixed-size elements contiguously and grows
 * geometrically. It is allocation-failure aware: every operation that can
 * allocate returns a `util_status` so callers can handle OOM explicitly.
 */
#ifndef UTIL_DYN_ARRAY_H
#define UTIL_DYN_ARRAY_H

#include <stddef.h>
#include "util/status.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Optional per-element destructor, invoked on removal / array destruction. */
typedef void (*util_elem_dtor)(void *element);

typedef struct {
    unsigned char *data;     /* contiguous element storage             */
    size_t         count;    /* number of live elements                */
    size_t         capacity; /* number of elements that fit in `data`  */
    size_t         elem_size;/* size of a single element in bytes      */
    util_elem_dtor dtor;     /* optional element destructor (may be NULL) */
} util_dyn_array;

/*
 * Initialize an array for elements of `elem_size` bytes.
 * `dtor` may be NULL. Does not allocate; the first push allocates.
 * Returns UTIL_OK, or UTIL_ERR_INVALID if elem_size == 0.
 */
util_status util_dyn_array_init(util_dyn_array *arr, size_t elem_size,
                                util_elem_dtor dtor);

/* Reserve capacity for at least `min_capacity` elements. */
util_status util_dyn_array_reserve(util_dyn_array *arr, size_t min_capacity);

/*
 * Append a copy of `*element` (elem_size bytes) to the array.
 * Returns UTIL_ERR_NOMEM if growth fails (array left unchanged).
 */
util_status util_dyn_array_push(util_dyn_array *arr, const void *element);

/*
 * Pointer to element at `index`, or NULL if out of range.
 * The pointer is invalidated by any mutating call.
 */
void *util_dyn_array_at(const util_dyn_array *arr, size_t index);

/* Remove the last element (runs dtor if set). No-op when empty. */
void util_dyn_array_pop(util_dyn_array *arr);

/* Number of live elements. */
size_t util_dyn_array_count(const util_dyn_array *arr);

/* Run dtor over all elements and reset count to 0 (keeps capacity). */
void util_dyn_array_clear(util_dyn_array *arr);

/* Destroy the array: clears elements and frees the backing buffer. */
void util_dyn_array_destroy(util_dyn_array *arr);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* UTIL_DYN_ARRAY_H */
