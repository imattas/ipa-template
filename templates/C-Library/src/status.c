#include "util/status.h"

const char *util_status_str(util_status status) {
    switch (status) {
        case UTIL_OK:           return "ok";
        case UTIL_ERR_INVALID:  return "invalid argument";
        case UTIL_ERR_NOMEM:    return "out of memory";
        case UTIL_ERR_RANGE:    return "index out of range";
        case UTIL_ERR_OVERFLOW: return "size overflow";
        default:                return "unknown status";
    }
}
