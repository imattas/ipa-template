import Foundation
import Observation

/// View model backing the Home screen.
///
/// Uses the iOS 17+ `@Observable` macro from the Observation framework.
///
/// Pre-iOS 17 fallback: conform to `ObservableObject` and mark mutable UI state
/// with `@Published` instead, e.g.
///
/// ```swift
/// final class HomeViewModel: ObservableObject {
///     @Published private(set) var items: [Item] = []
///     @Published private(set) var isLoading = false
///     @Published private(set) var errorMessage: String?
/// }
/// ```
///
/// The view would then observe via Combine (`$items.sink { ... }`) instead of
/// `withObservationTracking`.
@MainActor
@Observable
final class HomeViewModel {

    // MARK: - Observable State

    private(set) var items: [Item] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    // MARK: - Dependencies

    @ObservationIgnored
    private let apiClient: APIClientProtocol

    // MARK: - Init

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    // MARK: - Actions

    /// Loads the list of items from the API, updating loading/error/items state.
    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await apiClient.fetchItems()
            items = fetched
        } catch {
            // Surface a user-presentable message. In a real app you would map
            // `APIError` cases to localized strings.
            errorMessage = (error as? APIError)?.userMessage ?? error.localizedDescription
            items = []
        }

        isLoading = false
    }
}
