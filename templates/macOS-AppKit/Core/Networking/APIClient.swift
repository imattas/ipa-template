//
//  APIClient.swift
//  macOS-AppKit Template
//
//  Networking layer built on async/await + URLSession.
//

import Foundation

// MARK: - Model

/// A small example domain model. Replace with your real types.
struct Item: Codable, Identifiable, Sendable, Hashable {
    let id: Int
    let title: String
    let subtitle: String?

    init(id: Int, title: String, subtitle: String? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
    }
}

// MARK: - Errors

/// Typed errors surfaced by the networking layer.
enum APIError: Error, LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case unacceptableStatusCode(Int)
    case decodingFailed
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The request URL was invalid."
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .unacceptableStatusCode(let code):
            return "The server returned status code \(code)."
        case .decodingFailed:
            return "The response could not be decoded."
        case .transport(let message):
            return message
        }
    }
}

// MARK: - Protocol

/// Abstraction over the networking layer so view models can be tested with mocks.
protocol APIClientProtocol: Sendable {
    /// Sends an endpoint and decodes the JSON response into `T`.
    func send<T: Decodable & Sendable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T

    /// Convenience for the example items feed.
    func fetchItems() async throws -> [Item]
}

// MARK: - Live Client

/// Concrete networking client.
///
/// Implemented as an `actor` so that any mutable state (e.g. caches, in-flight
/// request tracking) added later is automatically isolated and `Sendable`-safe.
actor APIClient: APIClientProtocol {

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    /// - Parameters:
    ///   - baseURL: API root. TODO: Point this at your real backend.
    ///   - session: Injected for testability. Defaults to `.shared`.
    init(
        baseURL: URL = URL(string: "https://api.example.com")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }

    func send<T: Decodable & Sendable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T {
        guard let request = endpoint.urlRequest(baseURL: baseURL) else {
            throw APIError.invalidURL
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
            throw APIError.unacceptableStatusCode(http.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func fetchItems() async throws -> [Item] {
        try await send(.items, as: [Item].self)
    }
}

// MARK: - Mock Client (for tests & previews)

/// In-memory client used by unit tests and during development.
final class MockAPIClient: APIClientProtocol, @unchecked Sendable {

    /// Items returned by `fetchItems()` on success.
    var stubbedItems: [Item]

    /// When set, every call throws this error instead of returning data.
    var stubbedError: Error?

    init(stubbedItems: [Item] = MockAPIClient.sampleItems, stubbedError: Error? = nil) {
        self.stubbedItems = stubbedItems
        self.stubbedError = stubbedError
    }

    func send<T: Decodable & Sendable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T {
        if let stubbedError { throw stubbedError }
        guard let items = stubbedItems as? T else {
            throw APIError.decodingFailed
        }
        return items
    }

    func fetchItems() async throws -> [Item] {
        if let stubbedError { throw stubbedError }
        return stubbedItems
    }

    /// Deterministic sample data for previews and tests.
    static let sampleItems: [Item] = [
        Item(id: 1, title: "First Item", subtitle: "An example row"),
        Item(id: 2, title: "Second Item", subtitle: "Another example row"),
        Item(id: 3, title: "Third Item", subtitle: nil)
    ]
}
