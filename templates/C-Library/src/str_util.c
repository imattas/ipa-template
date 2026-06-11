#include "util/str_util.h"

#include <ctype.h>
#include <stdlib.h>
#include <string.h>

#define UTIL_STR_MIN_CAP 16

void util_str_init(util_str *s) {
    if (s == NULL) {
        return;
    }
    s->data = NULL;
    s->length = 0;
    s->capacity = 0;
}

static util_status util_str_ensure(util_str *s, size_t needed_total) {
    /* needed_total includes space for the trailing NUL. */
    if (needed_total <= s->capacity) {
        return UTIL_OK;
    }
    size_t cap = s->capacity ? s->capacity : UTIL_STR_MIN_CAP;
    while (cap < needed_total) {
        if (cap > (size_t)-1 / 2) {
            return UTIL_ERR_OVERFLOW;
        }
        cap *= 2;
    }
    char *grown = realloc(s->data, cap);
    if (grown == NULL) {
        return UTIL_ERR_NOMEM;
    }
    if (s->data == NULL) {
        grown[0] = '\0';
    }
    s->data = grown;
    s->capacity = cap;
    return UTIL_OK;
}

util_status util_str_append_n(util_str *s, const char *bytes, size_t len) {
    if (s == NULL || (bytes == NULL && len > 0)) {
        return UTIL_ERR_INVALID;
    }
    if (len == 0) {
        return UTIL_OK;
    }
    util_status rc = util_str_ensure(s, s->length + len + 1);
    if (rc != UTIL_OK) {
        return rc;
    }
    memcpy(s->data + s->length, bytes, len);
    s->length += len;
    s->data[s->length] = '\0';
    return UTIL_OK;
}

util_status util_str_append(util_str *s, const char *cstr) {
    if (cstr == NULL) {
        return UTIL_ERR_INVALID;
    }
    return util_str_append_n(s, cstr, strlen(cstr));
}

util_status util_str_append_char(util_str *s, char c) {
    return util_str_append_n(s, &c, 1);
}

const char *util_str_cstr(const util_str *s) {
    if (s == NULL || s->data == NULL) {
        return "";
    }
    return s->data;
}

void util_str_clear(util_str *s) {
    if (s == NULL) {
        return;
    }
    s->length = 0;
    if (s->data) {
        s->data[0] = '\0';
    }
}

void util_str_destroy(util_str *s) {
    if (s == NULL) {
        return;
    }
    free(s->data);
    s->data = NULL;
    s->length = 0;
    s->capacity = 0;
}

char *util_strdup(const char *cstr) {
    if (cstr == NULL) {
        return NULL;
    }
    size_t len = strlen(cstr);
    char *copy = malloc(len + 1);
    if (copy == NULL) {
        return NULL;
    }
    memcpy(copy, cstr, len + 1);
    return copy;
}

char *util_str_trim(char *s) {
    if (s == NULL) {
        return s;
    }
    char *start = s;
    while (*start && isspace((unsigned char)*start)) {
        start++;
    }
    char *end = start + strlen(start);
    while (end > start && isspace((unsigned char)end[-1])) {
        end--;
    }
    *end = '\0';
    if (start != s) {
        memmove(s, start, (size_t)(end - start) + 1);
    }
    return s;
}

int util_str_ends_with(const char *s, const char *suffix) {
    if (s == NULL || suffix == NULL) {
        return 0;
    }
    size_t sl = strlen(s);
    size_t fl = strlen(suffix);
    if (fl > sl) {
        return 0;
    }
    return memcmp(s + sl - fl, suffix, fl) == 0 ? 1 : 0;
}
