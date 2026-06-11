import Foundation

/// View model for `HomeView`.
///
/// Uses the Swift `@Observable` macro (watchOS 10+) so SwiftUI views observe
/// only the properties they actually read.
///
/// > Note: Pre-watchOS 10 fallback — replace `@Observable` with
/// > `final class HomeViewModel: ObservableObject` and mark the published
/// > properties below with `@Published`. Then observe the view model with
/// > `@StateObject` / `@ObservedObject` in the view instead of `@State`.
@MainActor
@Observable
final class HomeViewModel {
    /// Items rendered by the list.
    private(set) var items: [Item] = []

    /// Whether a load is currently in flight.
    private(set) var isLoading = false

    /// A user-facing error message, if the last load failed.
    private(set) var errorMessage: String?

    private let apiClient: APIClientProtocol

    /// - Parameter apiClient: Injected networking dependency. Defaults to the
    ///   live `APIClient`; inject `MockAPIClient` in tests and previews.
    init(apiClient: APIClientProtocol = APIClient()) {
        self.apiClient = apiClient
    }

    /// Loads items from the API, updating loading/error state along the way.
    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            items = try await apiClient.fetchItems()
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription
                ?? error.localizedDescription
        }
    }
}
