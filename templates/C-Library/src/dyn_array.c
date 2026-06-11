#include "util/dyn_array.h"

#include <stdlib.h>
#include <string.h>

/* Geometric growth factor; doubling keeps amortized push O(1). */
#define UTIL_DYN_ARRAY_MIN_CAP 8

static void *elem_ptr(const util_dyn_array *arr, size_t index) {
    return arr->data + (index * arr->elem_size);
}

util_status util_dyn_array_init(util_dyn_array *arr, size_t elem_size,
                                util_elem_dtor dtor) {
    if (arr == NULL || elem_size == 0) {
        return UTIL_ERR_INVALID;
    }
    arr->data = NULL;
    arr->count = 0;
    arr->capacity = 0;
    arr->elem_size = elem_size;
    arr->dtor = dtor;
    return UTIL_OK;
}

util_status util_dyn_array_reserve(util_dyn_array *arr, size_t min_capacity) {
    if (arr == NULL) {
        return UTIL_ERR_INVALID;
    }
    if (min_capacity <= arr->capacity) {
        return UTIL_OK;
    }

    /* Guard against multiplication overflow when sizing the allocation. */
    if (min_capacity > (size_t)-1 / arr->elem_size) {
        return UTIL_ERR_OVERFLOW;
    }

    unsigned char *grown = realloc(arr->data, min_capacity * arr->elem_size);
    if (grown == NULL) {
        return UTIL_ERR_NOMEM;
    }
    arr->data = grown;
    arr->capacity = min_capacity;
    return UTIL_OK;
}

util_status util_dyn_array_push(util_dyn_array *arr, const void *element) {
    if (arr == NULL || element == NULL) {
        return UTIL_ERR_INVALID;
    }
    if (arr->count == arr->capacity) {
        size_t next = arr->capacity ? arr->capacity * 2 : UTIL_DYN_ARRAY_MIN_CAP;
        util_status rc = util_dyn_array_reserve(arr, next);
        if (rc != UTIL_OK) {
            return rc;
        }
    }
    memcpy(elem_ptr(arr, arr->count), element, arr->elem_size);
    arr->count++;
    return UTIL_OK;
}

void *util_dyn_array_at(const util_dyn_array *arr, size_t index) {
    if (arr == NULL || index >= arr->count) {
        return NULL;
    }
    return elem_ptr(arr, index);
}

void util_dyn_array_pop(util_dyn_array *arr) {
    if (arr == NULL || arr->count == 0) {
        return;
    }
    arr->count--;
    if (arr->dtor) {
        arr->dtor(elem_ptr(arr, arr->count));
    }
}

size_t util_dyn_array_count(const util_dyn_array *arr) {
    return arr ? arr->count : 0;
}

void util_dyn_array_clear(util_dyn_array *arr) {
    if (arr == NULL) {
        return;
    }
    if (arr->dtor) {
        for (size_t i = 0; i < arr->count; ++i) {
            arr->dtor(elem_ptr(arr, i));
        }
    }
    arr->count = 0;
}

void util_dyn_array_destroy(util_dyn_array *arr) {
    if (arr == NULL) {
        return;
    }
    util_dyn_array_clear(arr);
    free(arr->data);
    arr->data = NULL;
    arr->capacity = 0;
}
