//
//  APIClient.swift
//  Swift-SwiftUI
//
//  Protocol-oriented networking layer built on URLSession and async/await.
//  Views and view models depend on `APIClientProtocol` (not the concrete type)
//  so they can be tested and previewed with `MockAPIClient`.
//

import Foundation

// MARK: - Model

/// A minimal domain model fetched from the API. Replace/extend for your app.
struct Item: Codable, Identifiable, Hashable, Sendable {
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

/// Typed networking errors surfaced to callers.
enum APIError: Error, LocalizedError, Equatable {
    case invalidURL
    case requestFailed(URLError)
    case invalidResponse
    case server(status: Int)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The request URL was invalid."
        case .requestFailed(let error):
            return "The request failed: \(error.localizedDescription)"
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .server(let status):
            return "The server returned an error (status \(status))."
        case .decoding(let detail):
            return "Failed to decode the response: \(detail)"
        }
    }

    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.invalidResponse, .invalidResponse):
            return true
        case let (.requestFailed(l), .requestFailed(r)):
            return l.code == r.code
        case let (.server(l), .server(r)):
            return l == r
        case let (.decoding(l), .decoding(r)):
            return l == r
        default:
            return false
        }
    }
}

// MARK: - Protocol

/// Abstraction over the networking layer. Conformers must be `Sendable` so they
/// can be shared safely across concurrency domains.
protocol APIClientProtocol: Sendable {
    /// Sends an endpoint and decodes the response body into `T`.
    func send<T: Decodable>(_ endpoint: Endpoint) async throws -> T

    /// Concrete convenience for the home feature.
    func fetchItems() async throws -> [Item]
}

// MARK: - Live implementation

/// Default URLSession-backed client. Modeled as an `actor` so its mutable
/// configuration is isolated and access is serialized.
actor APIClient: APIClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        baseURL: URL = URL(string: "https://api.example.com")!, // TODO: configure
        session: URLSession = .shared,
        decoder: JSONDecoder = APIClient.makeDecoder()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
    }

    func send<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let request = try endpoint.urlRequest(baseURL: baseURL)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw APIError.requestFailed(urlError)
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
            throw APIError.decoding(String(describing: error))
        }
    }

    func fetchItems() async throws -> [Item] {
        try await send(.items)
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}

// MARK: - Mock implementation

/// In-memory client for previews and tests. Configure `items`, an injected
/// `error`, and an optional `delay` to simulate network latency.
final class MockAPIClient: APIClientProtocol, @unchecked Sendable {
    var items: [Item]
    var error: Error?
    var delay: Duration

    init(
        items: [Item] = MockAPIClient.sampleItems,
        error: Error? = nil,
        delay: Duration = .zero
    ) {
        self.items = items
        self.error = error
        self.delay = delay
    }

    func send<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        if let error { throw error }
        if delay != .zero { try? await Task.sleep(for: delay) }
        // The template only mocks the items endpoint; extend as needed.
        if let typed = items as? T {
            return typed
        }
        throw APIError.invalidResponse
    }

    func fetchItems() async throws -> [Item] {
        if let error { throw error }
        if delay != .zero { try? await Task.sleep(for: delay) }
        return items
    }

    static let sampleItems: [Item] = [
        Item(id: 1, title: "Welcome", subtitle: "Your first item"),
        Item(id: 2, title: "Networking", subtitle: "Powered by async/await"),
        Item(id: 3, title: "Navigation", subtitle: "Driven by AppRouter")
    ]
}
