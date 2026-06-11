// task_queue.hpp — a thread-safe FIFO work queue with blocking pop.
//
// A bounded-free, multi-producer / multi-consumer queue suitable as the core
// of a background worker pool. Demonstrates condition-variable coordination
// and clean shutdown semantics.
#pragma once

#include <condition_variable>
#include <mutex>
#include <optional>
#include <queue>
#include <utility>

namespace appcore {

template <typename T>
class TaskQueue {
public:
    TaskQueue() = default;
    TaskQueue(const TaskQueue&) = delete;
    TaskQueue& operator=(const TaskQueue&) = delete;

    // Enqueue an item. No-op once the queue has been closed.
    void push(T item) {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            if (closed_) return;
            queue_.push(std::move(item));
        }
        not_empty_.notify_one();
    }

    // Block until an item is available or the queue is closed and drained.
    // Returns std::nullopt only when the queue is closed and empty.
    std::optional<T> wait_pop() {
        std::unique_lock<std::mutex> lock(mutex_);
        not_empty_.wait(lock, [this] { return !queue_.empty() || closed_; });
        if (queue_.empty()) {
            return std::nullopt;  // closed and drained
        }
        T item = std::move(queue_.front());
        queue_.pop();
        return item;
    }

    // Non-blocking pop; std::nullopt if currently empty.
    std::optional<T> try_pop() {
        std::lock_guard<std::mutex> lock(mutex_);
        if (queue_.empty()) {
            return std::nullopt;
        }
        T item = std::move(queue_.front());
        queue_.pop();
        return item;
    }

    // Wake all waiters; subsequent wait_pop() drains then returns nullopt.
    void close() {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            closed_ = true;
        }
        not_empty_.notify_all();
    }

    [[nodiscard]] std::size_t size() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return queue_.size();
    }

    [[nodiscard]] bool closed() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return closed_;
    }

private:
    mutable std::mutex mutex_;
    std::condition_variable not_empty_;
    std::queue<T> queue_;
    bool closed_ = false;
};

}  // namespace appcore
