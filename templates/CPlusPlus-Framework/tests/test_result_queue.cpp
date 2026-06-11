#include "appcore/result.hpp"
#include "appcore/task_queue.hpp"
#include "test_appcore.hpp"

#include <string>
#include <thread>

// Test 1: Result carries success and failure states and maps the value.
static bool test_result_states() {
    using R = appcore::Result<int>;

    R ok = R::success(21);
    CHECK(ok.is_ok());
    CHECK(static_cast<bool>(ok));
    CHECK(ok.value() == 21);
    CHECK(ok.map([](int v) { return v * 2; }).value() == 42);

    R bad = R::failure(appcore::Error{404, "not found"});
    CHECK(bad.is_error());
    CHECK(!bad);
    CHECK(bad.value_or(-1) == -1);
    CHECK(bad.error().code == 404);
    // map preserves the error.
    CHECK(bad.map([](int v) { return v + 1; }).is_error());
    return true;
}

// Test 2: TaskQueue delivers items across a producer/consumer thread and
// shuts down cleanly via close().
static bool test_task_queue_threaded() {
    appcore::TaskQueue<int> queue;

    std::thread producer([&] {
        for (int i = 1; i <= 5; ++i) {
            queue.push(i);
        }
        queue.close();
    });

    int sum = 0;
    int count = 0;
    while (auto item = queue.wait_pop()) {
        sum += *item;
        ++count;
    }
    producer.join();

    CHECK(count == 5);
    CHECK(sum == 15);
    CHECK(queue.closed());
    CHECK(!queue.wait_pop().has_value());  // stays drained
    return true;
}

// Test 3: try_pop is non-blocking and respects FIFO order.
static bool test_try_pop_fifo() {
    appcore::TaskQueue<std::string> queue;
    CHECK(!queue.try_pop().has_value());

    queue.push("a");
    queue.push("b");
    CHECK(queue.size() == 2);
    CHECK(*queue.try_pop() == "a");
    CHECK(*queue.try_pop() == "b");
    CHECK(!queue.try_pop().has_value());
    return true;
}

TEST_MAIN_BEGIN()
    std::printf("result + task_queue tests\n");
    RUN_TEST(test_result_states);
    RUN_TEST(test_task_queue_threaded);
    RUN_TEST(test_try_pop_fifo);
TEST_MAIN_END()
