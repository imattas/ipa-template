//
//  UserDefaultsManager.swift
//  macOS-AppKit Template
//
//  Typed wrapper around UserDefaults for app preferences.
//

import Foundation

/// Centralized, typed access to user preferences.
///
/// Using a single manager keeps key strings in one place and gives call sites
/// strongly-typed accessors instead of stringly-typed `UserDefaults` lookups.
final class UserDefaultsManager: @unchecked Sendable {

    /// Shared instance. Inject a custom instance in tests if needed.
    static let shared = UserDefaultsManager()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Preference keys. Add new keys here.
    private enum Key {
        static let username = "preferences.username"
        static let notificationsEnabled = "preferences.notificationsEnabled"
        static let refreshInterval = "preferences.refreshInterval"
        static let hasCompletedOnboarding = "preferences.hasCompletedOnboarding"
    }

    // MARK: - Typed Accessors

    var username: String {
        get { defaults.string(forKey: Key.username) ?? "" }
        set { defaults.set(newValue, forKey: Key.username) }
    }

    var notificationsEnabled: Bool {
        get { defaults.bool(forKey: Key.notificationsEnabled) }
        set { defaults.set(newValue, forKey: Key.notificationsEnabled) }
    }

    /// Auto-refresh interval in seconds. Defaults to 60 when unset.
    var refreshInterval: Int {
        get {
            let stored = defaults.integer(forKey: Key.refreshInterval)
            return stored == 0 ? 60 : stored
        }
        set { defaults.set(newValue, forKey: Key.refreshInterval) }
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Key.hasCompletedOnboarding) }
    }

    // MARK: - Utilities

    /// Removes all keys managed here. Useful for "Reset" actions and tests.
    func reset() {
        [Key.username, Key.notificationsEnabled, Key.refreshInterval, Key.hasCompletedOnboarding]
            .forEach { defaults.removeObject(forKey: $0) }
    }
}
