// test_appcore.hpp — a minimal, dependency-free C++ test harness.
//
// Avoids pulling in GoogleTest/Catch2 so the framework builds anywhere with
// just a C++17 compiler. Define test functions returning bool (true == pass)
// and register them with RUN_TEST inside a TEST_MAIN block.
#pragma once

#include <cstdio>
#include <string>

namespace test {

inline int g_run = 0;
inline int g_failed = 0;

}  // namespace test

#define CHECK(cond)                                                          \
    do {                                                                     \
        if (!(cond)) {                                                       \
            std::printf("  FAIL: %s:%d: CHECK(%s)\n", __FILE__, __LINE__,    \
                        #cond);                                              \
            return false;                                                    \
        }                                                                    \
    } while (0)

#define RUN_TEST(fn)                                                         \
    do {                                                                     \
        ::test::g_run++;                                                     \
        std::printf("- %s\n", #fn);                                          \
        if (!fn()) ::test::g_failed++;                                       \
    } while (0)

#define TEST_MAIN_BEGIN() int main() {
#define TEST_MAIN_END()                                                      \
    std::printf("\n%d run, %d failed\n", ::test::g_run, ::test::g_failed);   \
    return ::test::g_failed == 0 ? 0 : 1;                                    \
    }
