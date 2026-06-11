#include "util.h"
#include "test_util.h"

#include <string.h>
#include <stdlib.h>

/* Test 1: the string builder appends and stays NUL-terminated. */
static int test_builder_append(void) {
    util_str s;
    util_str_init(&s);

    CHECK(util_str_append(&s, "hello") == UTIL_OK);
    CHECK(util_str_append_char(&s, ',') == UTIL_OK);
    CHECK(util_str_append(&s, " world") == UTIL_OK);

    CHECK(strcmp(util_str_cstr(&s), "hello, world") == 0);
    CHECK_EQ_INT(s.length, 12);

    util_str_clear(&s);
    CHECK_EQ_INT(s.length, 0);
    CHECK(strcmp(util_str_cstr(&s), "") == 0);

    util_str_destroy(&s);
    return 0;
}

/* Test 2: trim and ends_with helpers. */
static int test_trim_and_suffix(void) {
    char *dup = util_strdup("  padded text \t");
    CHECK(dup != NULL);
    CHECK(strcmp(util_str_trim(dup), "padded text") == 0);
    free(dup);

    CHECK(util_str_ends_with("report.json", ".json") == 1);
    CHECK(util_str_ends_with("report.json", ".csv") == 0);
    CHECK(util_str_ends_with("hi", "longer") == 0);
    return 0;
}

/* Test 3: version string is wired up. */
static int test_version(void) {
    CHECK(strcmp(util_version(), UTIL_VERSION_STRING) == 0);
    return 0;
}

TEST_MAIN_BEGIN()
    printf("str_util tests\n");
    RUN_TEST(test_builder_append);
    RUN_TEST(test_trim_and_suffix);
    RUN_TEST(test_version);
TEST_MAIN_END()
