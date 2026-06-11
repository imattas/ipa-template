import Foundation

/// Supported HTTP methods.
enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// A value type describing a single API request, independent of any base URL.
///
/// Build a concrete `URLRequest` with `urlRequest(baseURL:)`.
struct Endpoint: Sendable {

    let path: String
    var method: HTTPMethod = .get
    var queryItems: [URLQueryItem] = []
    var headers: [String: String] = [:]
    var body: Data?

    /// Constructs a `URLRequest` for this endpoint relative to `baseURL`.
    /// - Throws: `APIError.invalidURL` if the components cannot form a valid URL.
    func urlRequest(baseURL: URL) throws -> URLRequest {
        let pathURL = baseURL.appendingPathComponent(path)
        guard var components = URLComponents(url: pathURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body

        // Sensible defaults; per-endpoint headers override these.
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

// MARK: - Convenience constructors

extension Endpoint {
    /// Example endpoint used by `APIClient.fetchItems()`.
    static var items: Endpoint {
        Endpoint(path: "items", method: .get)
    }
}
