//
//  HomeViewModel.swift
//  Swift-SwiftUI
//
//  View model for the Home feature. Loads items from the injected API client
//  and exposes presentation state for HomeView to render.
//

import Foundation

// NOTE: This uses the Observation framework (@Observable), available on
// iOS 17 / macOS 14+. For earlier deployment targets, replace `@Observable`
// with `: ObservableObject` and annotate the published properties with
// `@Published`, then observe with `@StateObject`/`@ObservedObject` in the view.
@Observable
@MainActor
final class HomeViewModel {
    /// The loaded items, rendered as a list.
    private(set) var items: [Item] = []
    /// True while a load is in flight (drives the loading UI).
    private(set) var isLoading = false
    /// A user-facing error message, or nil when there is no error.
    private(set) var errorMessage: String?

    private let api: any APIClientProtocol

    /// - Parameter api: The networking dependency. Inject `MockAPIClient` for
    ///   previews and tests.
    init(api: any APIClientProtocol) {
        self.api = api
    }

    /// Loads items from the API, updating loading/error state along the way.
    /// Safe to call repeatedly (e.g. from `.task` and pull-to-refresh).
    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            items = try await api.fetchItems()
        } catch is CancellationError {
            // Ignore cancellations (e.g. view dismissed mid-load).
        } catch {
            errorMessage = (error as? APIError)?.errorDescription
                ?? error.localizedDescription
        }
    }
}
