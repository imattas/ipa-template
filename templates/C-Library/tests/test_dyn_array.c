#include "util.h"
#include "test_util.h"

/* Test 1: pushing past the initial capacity grows and preserves order. */
static int test_push_and_grow(void) {
    util_dyn_array arr;
    CHECK(util_dyn_array_init(&arr, sizeof(int), NULL) == UTIL_OK);

    for (int i = 0; i < 100; ++i) {
        CHECK(util_dyn_array_push(&arr, &i) == UTIL_OK);
    }
    CHECK_EQ_INT(util_dyn_array_count(&arr), 100);
    CHECK(arr.capacity >= 100);

    for (int i = 0; i < 100; ++i) {
        int *p = (int *)util_dyn_array_at(&arr, (size_t)i);
        CHECK(p != NULL);
        CHECK_EQ_INT(*p, i);
    }

    util_dyn_array_destroy(&arr);
    return 0;
}

/* Test 2: bounds, pop, and clear behave as documented. */
static int test_bounds_pop_clear(void) {
    util_dyn_array arr;
    CHECK(util_dyn_array_init(&arr, sizeof(int), NULL) == UTIL_OK);

    int a = 10, b = 20;
    CHECK(util_dyn_array_push(&arr, &a) == UTIL_OK);
    CHECK(util_dyn_array_push(&arr, &b) == UTIL_OK);

    CHECK(util_dyn_array_at(&arr, 2) == NULL);   /* out of range */

    util_dyn_array_pop(&arr);
    CHECK_EQ_INT(util_dyn_array_count(&arr), 1);
    CHECK_EQ_INT(*(int *)util_dyn_array_at(&arr, 0), 10);

    util_dyn_array_clear(&arr);
    CHECK_EQ_INT(util_dyn_array_count(&arr), 0);

    util_dyn_array_destroy(&arr);
    return 0;
}

/* Test 3: init rejects a zero element size. */
static int test_invalid_init(void) {
    util_dyn_array arr;
    CHECK(util_dyn_array_init(&arr, 0, NULL) == UTIL_ERR_INVALID);
    return 0;
}

TEST_MAIN_BEGIN()
    printf("dyn_array tests\n");
    RUN_TEST(test_push_and_grow);
    RUN_TEST(test_bounds_pop_clear);
    RUN_TEST(test_invalid_init);
TEST_MAIN_END()
