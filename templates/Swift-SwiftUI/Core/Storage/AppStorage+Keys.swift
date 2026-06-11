//
//  AppStorage+Keys.swift
//  Swift-SwiftUI
//
//  A namespaced catalog of persisted keys plus typed @AppStorage helpers so
//  feature code never hard-codes raw string keys.
//

import SwiftUI

/// Central namespace for all UserDefaults-backed keys. Keeping these in one
/// place avoids typos and makes it easy to audit what the app persists.
enum StorageKeys {
    /// Whether the user has completed onboarding.
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    /// The user's preferred color scheme override (see `AppColorScheme`).
    static let appColorScheme = "appColorScheme"
    /// Whether analytics collection is enabled.
    static let isAnalyticsEnabled = "isAnalyticsEnabled"
    // TODO: Add new persisted keys here.
}

/// A persistable representation of the user's color scheme preference.
enum AppColorScheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Typed @AppStorage helpers
//
// These property wrappers can be dropped directly into a View or @Observable
// view model context. They centralize the key + default value pairing.

extension AppStorage where Value == Bool {
    /// `@AppStorage` for the onboarding flag.
    init(onboardingCompleted: Void) {
        self.init(wrappedValue: false, StorageKeys.hasCompletedOnboarding)
    }

    /// `@AppStorage` for the analytics flag.
    init(analyticsEnabled: Void) {
        self.init(wrappedValue: true, StorageKeys.isAnalyticsEnabled)
    }
}

extension AppStorage where Value == AppColorScheme {
    /// `@AppStorage` for the color-scheme preference (RawRepresentable backed).
    init(colorScheme: Void) {
        self.init(wrappedValue: .system, StorageKeys.appColorScheme)
    }
}

// Usage example inside a view:
//
//   @AppStorage(colorScheme: ()) private var scheme: AppColorScheme
//   @AppStorage(analyticsEnabled: ()) private var analytics: Bool
