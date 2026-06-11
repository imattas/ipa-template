//
//  Endpoint.swift
//  Swift-SwiftUI
//
//  A lightweight, value-type description of an HTTP endpoint. Endpoints are
//  composed independently of the client and turned into a URLRequest against a
//  base URL by `urlRequest(baseURL:)`.
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

/// Describes a single API endpoint.
struct Endpoint: Sendable {
    /// Path appended to the base URL, e.g. "/items".
    var path: String
    var method: HTTPMethod
    var query: [String: String]
    var headers: [String: String]
    var body: Data?

    init(
        path: String,
        method: HTTPMethod = .get,
        query: [String: String] = [:],
        headers: [String: String] = [:],
        body: Data? = nil
    ) {
        self.path = path
        self.method = method
        self.query = query
        self.headers = headers
        self.body = body
    }

    /// Builds a `URLRequest` by resolving this endpoint against `baseURL`.
    /// Throws `APIError.invalidURL` if the components cannot form a valid URL.
    func urlRequest(baseURL: URL) throws -> URLRequest {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL
        }

        if !query.isEmpty {
            components.queryItems = query
                .sorted { $0.key < $1.key }
                .map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

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

// MARK: - Convenience factories

extension Endpoint {
    /// The endpoint used to fetch the home item list.
    static var items: Endpoint {
        Endpoint(path: "/items")
    }
}
