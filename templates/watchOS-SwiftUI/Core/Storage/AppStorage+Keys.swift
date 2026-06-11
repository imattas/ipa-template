import Foundation

/// Namespaced keys for `@AppStorage` / `UserDefaults`-backed values.
///
/// Centralizing keys here avoids typos and accidental collisions across the app.
enum AppStorageKeys {
    /// Whether local/push notifications are enabled. `Bool`.
    static let notificationsEnabled = "settings.notificationsEnabled"

    /// Whether haptic feedback is enabled. `Bool`.
    static let hapticsEnabled = "settings.hapticsEnabled"

    /// Timestamp of the last successful background refresh. `Double` (epoch).
    static let lastRefreshDate = "state.lastRefreshDate"
}
