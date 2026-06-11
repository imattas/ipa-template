// event_bus.hpp — a tiny, type-erased publish/subscribe event bus.
//
// Subscribers register a callback for a named topic and receive a payload
// string when anyone publishes to that topic. Subscriptions are RAII: the
// returned token unsubscribes on destruction. Thread-safe.
#pragma once

#include <functional>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>

namespace appcore {

class EventBus {
public:
    using Handler = std::function<void(const std::string& payload)>;

    // RAII subscription token. Unsubscribes automatically when destroyed.
    class Subscription {
    public:
        Subscription() = default;
        Subscription(EventBus* bus, std::string topic, std::uint64_t id)
            : bus_(bus), topic_(std::move(topic)), id_(id) {}

        Subscription(Subscription&& other) noexcept { move_from(std::move(other)); }
        Subscription& operator=(Subscription&& other) noexcept {
            if (this != &other) {
                reset();
                move_from(std::move(other));
            }
            return *this;
        }
        Subscription(const Subscription&) = delete;
        Subscription& operator=(const Subscription&) = delete;

        ~Subscription() { reset(); }

        // Cancel the subscription early.
        void reset();

        [[nodiscard]] bool active() const noexcept { return bus_ != nullptr; }

    private:
        void move_from(Subscription&& other) noexcept {
            bus_ = other.bus_;
            topic_ = std::move(other.topic_);
            id_ = other.id_;
            other.bus_ = nullptr;
        }

        EventBus* bus_ = nullptr;
        std::string topic_;
        std::uint64_t id_ = 0;
    };

    EventBus() = default;
    EventBus(const EventBus&) = delete;
    EventBus& operator=(const EventBus&) = delete;

    // Subscribe `handler` to `topic`. Keep the returned token alive to stay
    // subscribed; let it go out of scope to unsubscribe.
    [[nodiscard]] Subscription subscribe(const std::string& topic, Handler handler);

    // Deliver `payload` to every handler currently subscribed to `topic`.
    // Returns the number of handlers invoked.
    std::size_t publish(const std::string& topic, const std::string& payload);

    // Number of live subscriptions across all topics.
    [[nodiscard]] std::size_t subscriber_count() const;

private:
    friend class Subscription;

    struct Entry {
        std::uint64_t id;
        Handler handler;
    };

    void unsubscribe(const std::string& topic, std::uint64_t id);

    mutable std::mutex mutex_;
    std::unordered_map<std::string, std::vector<Entry>> topics_;
    std::uint64_t next_id_ = 1;
};

}  // namespace appcore
