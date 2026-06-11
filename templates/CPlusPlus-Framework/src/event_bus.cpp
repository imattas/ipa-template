#include "appcore/event_bus.hpp"

#include <algorithm>

namespace appcore {

void EventBus::Subscription::reset() {
    if (bus_ != nullptr) {
        bus_->unsubscribe(topic_, id_);
        bus_ = nullptr;
    }
}

EventBus::Subscription EventBus::subscribe(const std::string& topic, Handler handler) {
    std::lock_guard<std::mutex> lock(mutex_);
    const std::uint64_t id = next_id_++;
    topics_[topic].push_back(Entry{id, std::move(handler)});
    return Subscription(this, topic, id);
}

std::size_t EventBus::publish(const std::string& topic, const std::string& payload) {
    // Copy the handler list under lock, then invoke outside the lock so a
    // handler may (un)subscribe without deadlocking.
    std::vector<Handler> handlers;
    {
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = topics_.find(topic);
        if (it == topics_.end()) {
            return 0;
        }
        handlers.reserve(it->second.size());
        for (const Entry& entry : it->second) {
            handlers.push_back(entry.handler);
        }
    }
    for (const Handler& handler : handlers) {
        handler(payload);
    }
    return handlers.size();
}

std::size_t EventBus::subscriber_count() const {
    std::lock_guard<std::mutex> lock(mutex_);
    std::size_t total = 0;
    for (const auto& [topic, entries] : topics_) {
        total += entries.size();
    }
    return total;
}

void EventBus::unsubscribe(const std::string& topic, std::uint64_t id) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = topics_.find(topic);
    if (it == topics_.end()) {
        return;
    }
    auto& entries = it->second;
    entries.erase(std::remove_if(entries.begin(), entries.end(),
                                 [id](const Entry& e) { return e.id == id; }),
                  entries.end());
    if (entries.empty()) {
        topics_.erase(it);
    }
}

}  // namespace appcore
