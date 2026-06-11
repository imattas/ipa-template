// result.hpp — a small Result<T, E> type for error-as-value control flow.
//
// A header-only, allocation-free alternative to exceptions for APIs that want
// explicit, type-safe error propagation (the same ergonomics you get from
// Swift's `Result` / Rust's `Result`). C++17, uses std::variant.
#pragma once

#include <string>
#include <utility>
#include <variant>

namespace appcore {

// Default error payload: a code + message. Callers may substitute their own
// error type as the second template parameter.
struct Error {
    int code = 0;
    std::string message;

    Error() = default;
    Error(int c, std::string m) : code(c), message(std::move(m)) {}
};

template <typename T, typename E = Error>
class Result {
public:
    // Construct a success value.
    static Result success(T value) { return Result(std::in_place_index<0>, std::move(value)); }

    // Construct a failure value.
    static Result failure(E error) { return Result(std::in_place_index<1>, std::move(error)); }

    [[nodiscard]] bool is_ok() const noexcept { return storage_.index() == 0; }
    [[nodiscard]] bool is_error() const noexcept { return storage_.index() == 1; }
    explicit operator bool() const noexcept { return is_ok(); }

    // Access helpers. Precondition: the corresponding state holds.
    [[nodiscard]] const T& value() const& { return std::get<0>(storage_); }
    [[nodiscard]] T& value() & { return std::get<0>(storage_); }
    [[nodiscard]] T&& value() && { return std::get<0>(std::move(storage_)); }

    [[nodiscard]] const E& error() const& { return std::get<1>(storage_); }
    [[nodiscard]] E& error() & { return std::get<1>(storage_); }

    // Returns the success value, or `fallback` if this is an error.
    [[nodiscard]] T value_or(T fallback) const& {
        return is_ok() ? std::get<0>(storage_) : std::move(fallback);
    }

    // Transform the success value, preserving any error. Functional `map`.
    template <typename F>
    auto map(F&& fn) const -> Result<decltype(fn(std::declval<T>())), E> {
        using U = decltype(fn(std::declval<T>()));
        if (is_ok()) {
            return Result<U, E>::success(fn(std::get<0>(storage_)));
        }
        return Result<U, E>::failure(std::get<1>(storage_));
    }

private:
    template <std::size_t I, typename... Args>
    explicit Result(std::in_place_index_t<I> tag, Args&&... args)
        : storage_(tag, std::forward<Args>(args)...) {}

    std::variant<T, E> storage_;
};

}  // namespace appcore
