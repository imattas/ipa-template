import SwiftUI

/// The application entry point for the watchOS app.
///
/// Uses `WKApplicationDelegateAdaptor` to bridge into the WatchKit application
/// lifecycle (see `AppDelegate`) while keeping the UI fully declarative with SwiftUI.
@main
struct WatchApp: App {
    /// Bridges the SwiftUI app lifecycle to the classic WatchKit lifecycle.
    /// This is how you receive lifecycle callbacks and handle background refresh
    /// tasks on watchOS while still using the SwiftUI `App` protocol.
    @WKApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            // watchOS apps use a NavigationStack root for hierarchical navigation.
            NavigationStack {
                HomeView()
            }
        }
    }
}
