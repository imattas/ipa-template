import Foundation
import Observation

/// View model for the Settings screen.
///
/// Toggles are persisted through `UserDefaultsManager`. State is exposed via the
/// `@Observable` macro (iOS 17+). See `HomeViewModel` for the pre-iOS 17
/// `ObservableObject` / `@Published` fallback.
@MainActor
@Observable
final class SettingsViewModel {

    // MARK: - Observable State

    var isNotificationsEnabled: Bool {
        didSet { defaults.isNotificationsEnabled = isNotificationsEnabled }
    }

    var isDarkModePreferred: Bool {
        didSet { defaults.isDarkModePreferred = isDarkModePreferred }
    }

    // MARK: - Dependencies

    @ObservationIgnored
    private let defaults: UserDefaultsManager

    // MARK: - Init

    init(defaults: UserDefaultsManager = .shared) {
        self.defaults = defaults
        self.isNotificationsEnabled = defaults.isNotificationsEnabled
        self.isDarkModePreferred = defaults.isDarkModePreferred
    }

    // MARK: - Display

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}
