import Foundation

// MARK: - Model

/// A simple domain model returned by the example `items` endpoint.
struct Item: Codable, Identifiable, Sendable, Equatable {
    let id: UUID
    let title: String
    let subtitle: String?

    init(id: UUID = UUID(), title: String, subtitle: String? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
    }
}

// MARK: - Errors

/// Typed networking errors surfaced by `APIClient`.
enum APIError: Error, Sendable {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case server(status: Int)
    case decoding(Error)

    /// A user-presentable description suitable for an alert.
    var userMessage: String {
        switch self {
        case .invalidURL:
            return "The request could not be formed."
        case .requestFailed:
            return "The network request failed. Check your connection and try again."
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .server(let status):
            return "The server responded with an error (\(status))."
        case .decoding:
            return "The response could not be read."
        }
    }
}

// MARK: - Protocol

/// Abstraction over the network layer so view models can be tested with a mock.
protocol APIClientProtocol: Sendable {
    func send<T: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> T
    func fetchItems() async throws -> [Item]
}

// MARK: - Client

/// Concrete networking client built on `URLSession`.
///
/// Modeled as an `actor` so the shared `JSONDecoder`/session usage is isolated
/// and the type is `Sendable` for Swift 6 concurrency.
actor APIClient: APIClientProtocol {

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        baseURL: URL = URL(string: "https://api.example.com/v1")!,
        session: URLSession = .shared,
        decoder: JSONDecoder = APIClient.makeDecoder()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    /// Sends an endpoint and decodes the response body into `T`.
    func send<T: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> T {
        let request: URLRequest
        do {
            request = try endpoint.urlRequest(baseURL: baseURL)
        } catch let error as APIError {
            throw error
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.requestFailed(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            throw APIError.server(status: http.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    /// Concrete example call used by `HomeViewModel`.
    func fetchItems() async throws -> [Item] {
        // TODO: Point `Endpoint.items` at your real resource and remove the stub below.
        // Real implementation:
        // return try await send(.items)

        // Stubbed sample data so the template runs out of the box.
        try await Task.sleep(nanoseconds: 300_000_000)
        return [
            Item(title: "Welcome", subtitle: "Replace fetchItems() with a real call."),
            Item(title: "MVVM", subtitle: "View ↔ ViewModel ↔ APIClient"),
            Item(title: "Swift Concurrency", subtitle: "async / await + actors"),
        ]
    }
}
