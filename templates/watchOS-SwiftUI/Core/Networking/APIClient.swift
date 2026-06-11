import Foundation

// MARK: - Model

/// A minimal example domain model returned by the API.
struct Item: Codable, Identifiable, Sendable, Equatable {
    let id: Int
    let title: String
    let subtitle: String
}

// MARK: - Errors

/// Typed networking errors surfaced by `APIClient`.
enum APIError: Error, LocalizedError, Equatable {
    case invalidRequest
    case invalidResponse
    case statusCode(Int)
    case decoding(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "The request could not be constructed."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .statusCode(let code):
            return "The server responded with status \(code)."
        case .decoding(let detail):
            return "Failed to decode the response: \(detail)"
        case .transport(let detail):
            return "Network error: \(detail)"
        }
    }
}

// MARK: - Protocol

/// Abstraction over the networking layer to enable dependency injection and
/// testing. View models depend on this, not on the concrete `APIClient`.
protocol APIClientProtocol: Sendable {
    func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T
    func fetchItems() async throws -> [Item]
}

extension APIClientProtocol {
    /// Convenience overload that infers the decoded type from context.
    func send<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        try await send(endpoint, as: T.self)
    }
}

// MARK: - Live Client

/// Concrete networking client built on `URLSession`.
///
/// Implemented as an `actor` so its mutable state (if any is added later, such
/// as caching or in-flight request tracking) is isolated and `Sendable`-safe.
actor APIClient: APIClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        baseURL: URL = URL(string: "https://api.example.com")!,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
    }

    func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T {
        guard let request = endpoint.urlRequest(baseURL: baseURL) else {
            throw APIError.invalidRequest
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.statusCode(http.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }

    func fetchItems() async throws -> [Item] {
        // TODO: Point this at your real items endpoint.
        let endpoint = Endpoint(path: "/items")
        return try await send(endpoint, as: [Item].self)
    }
}

// MARK: - Mock Client

/// In-memory client for previews and unit tests.
///
/// Configure `result` to return items or to throw a specific `APIError`.
final class MockAPIClient: APIClientProtocol, @unchecked Sendable {
    var result: Result<[Item], Error>

    init(result: Result<[Item], Error> = .success(MockAPIClient.sampleItems)) {
        self.result = result
    }

    func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T {
        // Not used directly by tests; provided for protocol conformance.
        throw APIError.invalidResponse
    }

    func fetchItems() async throws -> [Item] {
        try result.get()
    }

    static let sampleItems: [Item] = [
        Item(id: 1, title: "Morning Run", subtitle: "5.2 km"),
        Item(id: 2, title: "Heart Rate", subtitle: "68 bpm"),
        Item(id: 3, title: "Steps", subtitle: "8,431")
    ]
}
