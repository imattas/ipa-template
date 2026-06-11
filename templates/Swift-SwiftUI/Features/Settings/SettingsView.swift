//
//  SettingsView.swift
//  Swift-SwiftUI
//
//  Settings screen. Demonstrates typed @AppStorage usage and router-based
//  back navigation.
//

import SwiftUI

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel

    @Environment(AppRouter.self) private var router

    // Typed persisted preferences (see AppStorage+Keys.swift).
    @AppStorage(colorScheme: ()) private var colorScheme: AppColorScheme
    @AppStorage(analyticsEnabled: ()) private var analyticsEnabled: Bool

    init(viewModel: SettingsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $colorScheme) {
                    ForEach(AppColorScheme.allCases) { scheme in
                        Text(scheme.rawValue.capitalized).tag(scheme)
                    }
                }
            }

            Section("Privacy") {
                Toggle("Share Analytics", isOn: $analyticsEnabled)
            }

            Section("Onboarding") {
                Button("Reset Onboarding") {
                    viewModel.resetOnboarding()
                }
            }

            Section {
                LabeledContent("Version", value: viewModel.appVersion)
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Home") {
                    router.popToRoot()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView(viewModel: SettingsViewModel())
    }
    .environment(AppRouter())
}
