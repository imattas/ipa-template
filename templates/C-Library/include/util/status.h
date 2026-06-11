/*
 * status.h — shared status / error codes for libutil.
 */
#ifndef UTIL_STATUS_H
#define UTIL_STATUS_H

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    UTIL_OK = 0,          /* success                                  */
    UTIL_ERR_INVALID,     /* invalid argument                         */
    UTIL_ERR_NOMEM,       /* allocation failure                       */
    UTIL_ERR_RANGE,       /* index / bounds error                     */
    UTIL_ERR_OVERFLOW     /* size computation would overflow          */
} util_status;

/* Human-readable, static string for a status code (never NULL). */
const char *util_status_str(util_status status);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* UTIL_STATUS_H */
