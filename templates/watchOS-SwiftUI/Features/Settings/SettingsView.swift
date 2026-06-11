import SwiftUI

/// Settings screen with preferences backed by `@AppStorage`.
struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()

    @AppStorage(AppStorageKeys.notificationsEnabled)
    private var notificationsEnabled = true

    @AppStorage(AppStorageKeys.hapticsEnabled)
    private var hapticsEnabled = true

    var body: some View {
        List {
            Section("Preferences") {
                Toggle("Notifications", isOn: $notificationsEnabled)
                Toggle("Haptics", isOn: $hapticsEnabled)
            }

            Section {
                Button("Reset Preferences", role: .destructive) {
                    viewModel.resetPreferences()
                }
            } footer: {
                Text("Version \(viewModel.appVersion)")
                    .font(.caption2)
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
