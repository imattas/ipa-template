//
//  SettingsViewModel.swift
//  macOS-AppKit Template
//
//  View model for the Settings feature.
//

import Foundation
import Observation

/// View model backing `SettingsViewController`, persisting to `UserDefaultsManager`.
///
/// Uses the `@Observable` macro (macOS 14+).
/// PRE-macOS 14 FALLBACK: replace `@Observable` with `ObservableObject` and
/// mark stored properties with `@Published` (see `HomeViewModel` for details).
@MainActor
@Observable
final class SettingsViewModel {

    // MARK: - Dependencies

    private let defaultsManager: UserDefaultsManager

    // MARK: - Observable State

    var username: String {
        didSet { defaultsManager.username = username }
    }

    var notificationsEnabled: Bool {
        didSet { defaultsManager.notificationsEnabled = notificationsEnabled }
    }

    var refreshInterval: Int {
        didSet { defaultsManager.refreshInterval = refreshInterval }
    }

    // MARK: - Init

    init(defaultsManager: UserDefaultsManager = .shared) {
        self.defaultsManager = defaultsManager
        // Seed state from persisted preferences.
        self.username = defaultsManager.username
        self.notificationsEnabled = defaultsManager.notificationsEnabled
        self.refreshInterval = defaultsManager.refreshInterval
    }

    // MARK: - Actions

    /// Restores defaults and re-seeds the observable state.
    func resetToDefaults() {
        defaultsManager.reset()
        username = defaultsManager.username
        notificationsEnabled = defaultsManager.notificationsEnabled
        refreshInterval = defaultsManager.refreshInterval
    }
}
