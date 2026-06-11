//
//  SettingsViewModel.swift
//  Swift-SwiftUI
//
//  View model for the Settings feature. Bridges persisted preferences and
//  exposes actions like resetting onboarding.
//

import Foundation

// NOTE: Uses the Observation framework (@Observable), iOS 17 / macOS 14+.
// Pre-iOS17/macOS14 fallback: conform to `ObservableObject` and use
// `@Published` for the stored properties below.
@Observable
@MainActor
final class SettingsViewModel {
    /// App version string for display, read from the bundle.
    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    init() {}

    /// Clears the onboarding flag so the user sees onboarding again.
    func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: StorageKeys.hasCompletedOnboarding)
        // TODO: Trigger any side effects (e.g. analytics event).
    }
}
