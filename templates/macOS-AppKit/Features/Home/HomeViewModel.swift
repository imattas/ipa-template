//
//  HomeViewModel.swift
//  macOS-AppKit Template
//
//  View model for the Home feature.
//

import Foundation
import Observation

/// View model backing `HomeViewController`.
///
/// Uses the `@Observable` macro (macOS 14+). The view controller observes
/// changes via `withObservationTracking` / explicit reloads.
///
/// PRE-macOS 14 FALLBACK:
/// If you must deploy below macOS 14, drop `@Observable` and instead:
///   final class HomeViewModel: ObservableObject {
///       @Published private(set) var items: [Item] = []
///       @Published private(set) var isLoading = false
///       @Published var errorMessage: String?
///   }
/// and have the controller subscribe to the publishers.
@MainActor
@Observable
final class HomeViewModel {

    // MARK: - Observable State

    /// Items shown in the table.
    private(set) var items: [Item] = []

    /// Whether a load is in flight (drives spinners / disabled refresh).
    private(set) var isLoading = false

    /// User-facing error message, or `nil` when there is no error.
    var errorMessage: String?

    // MARK: - Dependencies

    private let apiClient: APIClientProtocol

    /// - Parameter apiClient: Injected networking client. Defaults to a live `APIClient`.
    init(apiClient: APIClientProtocol = APIClient()) {
        self.apiClient = apiClient
    }

    // MARK: - Actions

    /// Loads items from the API, updating loading and error state.
    func loadItems() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let fetched = try await apiClient.fetchItems()
            items = fetched
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            items = []
        }
    }

    /// Convenience accessor for table data sources.
    var itemCount: Int { items.count }

    /// Returns the item at a row index, or `nil` if out of bounds.
    func item(at index: Int) -> Item? {
        guard items.indices.contains(index) else { return nil }
        return items[index]
    }
}
