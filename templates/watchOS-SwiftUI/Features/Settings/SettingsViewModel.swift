import Foundation

/// View model for `SettingsView`.
///
/// Most settings are bound directly to `@AppStorage` in the view, so this view
/// model is intentionally light. It exists to host any settings-related logic
/// (e.g. clearing caches, exporting data) that shouldn't live in the view.
///
/// > Note: Pre-watchOS 10 fallback — replace `@Observable` with
/// > `ObservableObject` + `@Published` as described in `HomeViewModel`.
@MainActor
@Observable
final class SettingsViewModel {
    /// The app version string shown in the footer.
    let appVersion: String

    init(bundle: Bundle = .main) {
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        self.appVersion = "\(version) (\(build))"
    }

    /// Resets persisted user preferences to their defaults.
    func resetPreferences() {
        // TODO: Reset any @AppStorage-backed values you want cleared.
        UserDefaults.standard.removeObject(forKey: AppStorageKeys.notificationsEnabled)
        UserDefaults.standard.removeObject(forKey: AppStorageKeys.hapticsEnabled)
    }
}
