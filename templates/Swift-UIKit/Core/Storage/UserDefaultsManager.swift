import Foundation

/// A thin, typed wrapper around `UserDefaults`.
///
/// Each stored value is declared with the `@UserDefault` property wrapper, which
/// keeps the key and default in one place and reads/writes lazily.
final class UserDefaultsManager: @unchecked Sendable {

    static let shared = UserDefaultsManager()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Property wrappers need access to the backing store; rebind them so
        // tests can inject a custom suite.
        _isNotificationsEnabled = UserDefault(key: Keys.notifications, defaultValue: true, store: defaults)
        _isDarkModePreferred = UserDefault(key: Keys.darkMode, defaultValue: false, store: defaults)
        _hasCompletedOnboarding = UserDefault(key: Keys.onboarding, defaultValue: false, store: defaults)
    }

    private enum Keys {
        static let notifications = "settings.notificationsEnabled"
        static let darkMode = "settings.darkModePreferred"
        static let onboarding = "app.hasCompletedOnboarding"
    }

    @UserDefault(key: Keys.notifications, defaultValue: true)
    var isNotificationsEnabled: Bool

    @UserDefault(key: Keys.darkMode, defaultValue: false)
    var isDarkModePreferred: Bool

    @UserDefault(key: Keys.onboarding, defaultValue: false)
    var hasCompletedOnboarding: Bool
}

/// Property wrapper persisting a value of type `Value` in `UserDefaults`.
@propertyWrapper
struct UserDefault<Value> {
    let key: String
    let defaultValue: Value
    var store: UserDefaults = .standard

    var wrappedValue: Value {
        get { store.object(forKey: key) as? Value ?? defaultValue }
        set { store.set(newValue, forKey: key) }
    }
}
