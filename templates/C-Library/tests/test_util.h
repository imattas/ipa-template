/*
 * test_util.h — a minimal, dependency-free unit-test harness.
 *
 * Keeps the library buildable on any C11 toolchain without pulling in a
 * test framework. Each test file defines test functions and registers them
 * from main() via RUN_TEST.
 */
#ifndef TEST_UTIL_H
#define TEST_UTIL_H

#include <stdio.h>

extern int g_tests_run;
extern int g_tests_failed;

#define CHECK(cond)                                                        \
    do {                                                                   \
        if (!(cond)) {                                                     \
            printf("  FAIL: %s:%d: CHECK(%s)\n", __FILE__, __LINE__, #cond);\
            return 1;                                                      \
        }                                                                  \
    } while (0)

#define CHECK_EQ_INT(a, b)                                                 \
    do {                                                                   \
        long _a = (long)(a), _b = (long)(b);                               \
        if (_a != _b) {                                                    \
            printf("  FAIL: %s:%d: %s (%ld) != %s (%ld)\n",                \
                   __FILE__, __LINE__, #a, _a, #b, _b);                    \
            return 1;                                                      \
        }                                                                  \
    } while (0)

#define RUN_TEST(fn)                                                       \
    do {                                                                   \
        g_tests_run++;                                                     \
        printf("- %s\n", #fn);                                             \
        if (fn() != 0) {                                                   \
            g_tests_failed++;                                              \
        }                                                                  \
    } while (0)

#define TEST_MAIN_BEGIN()                                                  \
    int g_tests_run = 0;                                                   \
    int g_tests_failed = 0;                                               \
    int main(void) {

#define TEST_MAIN_END()                                                    \
        printf("\n%d run, %d failed\n", g_tests_run, g_tests_failed);      \
        return g_tests_failed == 0 ? 0 : 1;                                \
    }

#endif /* TEST_UTIL_H */
