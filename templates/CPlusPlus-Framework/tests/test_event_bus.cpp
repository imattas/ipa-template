#include "appcore/event_bus.hpp"
#include "appcore/version.hpp"
#include "test_appcore.hpp"

#include <string>

// Test 1: a published payload reaches a live subscriber.
static bool test_publish_delivers() {
    appcore::EventBus bus;
    std::string received;
    auto sub = bus.subscribe("metrics", [&](const std::string& p) { received = p; });

    const std::size_t delivered = bus.publish("metrics", "cpu=42");
    CHECK(delivered == 1);
    CHECK(received == "cpu=42");
    return true;
}

// Test 2: RAII subscription unsubscribes when the token is destroyed.
static bool test_raii_unsubscribe() {
    appcore::EventBus bus;
    int hits = 0;
    {
        auto sub = bus.subscribe("topic", [&](const std::string&) { ++hits; });
        CHECK(bus.subscriber_count() == 1);
        CHECK(bus.publish("topic", "x") == 1);
    }  // sub goes out of scope here
    CHECK(bus.subscriber_count() == 0);
    CHECK(bus.publish("topic", "y") == 0);  // no live subscribers
    CHECK(hits == 1);
    return true;
}

// Test 3: version string is wired up.
static bool test_version() {
    CHECK(appcore::version() == "0.1.0");
    return true;
}

TEST_MAIN_BEGIN()
    std::printf("event_bus tests\n");
    RUN_TEST(test_publish_delivers);
    RUN_TEST(test_raii_unsubscribe);
    RUN_TEST(test_version);
TEST_MAIN_END()
