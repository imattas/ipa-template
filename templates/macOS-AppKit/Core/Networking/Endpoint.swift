//
//  Endpoint.swift
//  macOS-AppKit Template
//
//  Lightweight value type describing a single HTTP endpoint.
//

import Foundation

/// Supported HTTP methods.
enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// Describes a request relative to a base URL.
///
/// `Endpoint` is intentionally transport-agnostic: it only knows how to build
/// a `URLRequest`. The actual networking lives in `APIClient`.
struct Endpoint: Sendable {

    /// Path appended to the base URL, e.g. `/items`.
    let path: String

    /// HTTP method. Defaults to `.get`.
    let method: HTTPMethod

    /// Query items appended to the URL.
    let queryItems: [URLQueryItem]

    /// Additional HTTP header fields.
    let headers: [String: String]

    /// Optional request body (already-encoded data).
    let body: Data?

    init(
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Data? = nil
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
    }

    /// Builds a `URLRequest` against the supplied base URL.
    /// - Parameter baseURL: The API root, e.g. `https://api.example.com`.
    /// - Returns: A configured request, or `nil` if the URL could not be formed.
    func urlRequest(baseURL: URL) -> URLRequest? {
        // Resolve the path against the base URL.
        let resolved = baseURL.appendingPathComponent(path)

        guard var components = URLComponents(url: resolved, resolvingAgainstBaseURL: false) else {
            return nil
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body

        // Sensible JSON defaults; callers may override via `headers`.
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }

        return request
    }
}

// MARK: - Common Endpoints

extension Endpoint {
    /// Example endpoint used by `APIClient.fetchItems()`.
    /// TODO: Replace with your real API routes.
    static let items = Endpoint(path: "items")
}
