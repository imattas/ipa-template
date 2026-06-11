//
//  AppEntry.swift
//  Swift-SwiftUI
//
//  The @main entry point for the application.
//  Owns the AppRouter and wires up the root NavigationStack.
//

import SwiftUI

@main
struct AppEntry: App {
    /// The app-wide navigation router. Held as @State so SwiftUI keeps a single
    /// instance alive for the lifetime of the scene. Injected into the
    /// environment so any descendant view can drive navigation.
    @State private var router = AppRouter()

    /// A single shared API client. In a larger app you would resolve this from
    /// a DI container; here we inject the concrete client (swap with
    /// `MockAPIClient()` for offline/UI testing).
    @State private var apiClient: any APIClientProtocol = APIClient()

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $router.path) {
                HomeView(viewModel: HomeViewModel(api: apiClient))
                    .navigationDestination(for: AppRouter.Route.self) { route in
                        destination(for: route)
                    }
            }
            .environment(router)
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        #endif
    }

    /// Maps a typed route to its destination view. Centralizing this here keeps
    /// individual views free of knowledge about the full route graph.
    @ViewBuilder
    private func destination(for route: AppRouter.Route) -> some View {
        switch route {
        case .home:
            HomeView(viewModel: HomeViewModel(api: apiClient))
        case .settings:
            SettingsView(viewModel: SettingsViewModel())
        case .detail(let id):
            // TODO: Replace with a dedicated DetailView that loads by id.
            DetailPlaceholderView(itemID: id)
        }
    }
}

/// Temporary detail screen. Swap for a real feature view under Features/Detail.
private struct DetailPlaceholderView: View {
    let itemID: Item.ID

    var body: some View {
        ContentUnavailableView(
            "Detail \(itemID)",
            systemImage: "doc.text",
            description: Text("TODO: Build the detail feature for item \(itemID).")
        )
        .navigationTitle("Detail")
    }
}
