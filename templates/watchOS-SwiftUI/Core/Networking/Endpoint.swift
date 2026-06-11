import Foundation

/// HTTP methods supported by `Endpoint`.
enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// A value type describing a single API endpoint.
///
/// Build a `URLRequest` from an endpoint with `urlRequest(baseURL:)`.
struct Endpoint: Sendable {
    let path: String
    var method: HTTPMethod = .get
    var queryItems: [URLQueryItem] = []
    var headers: [String: String] = [:]
    var body: Data?

    /// Constructs a `URLRequest` by resolving the endpoint against a base URL.
    /// - Parameter baseURL: The API root, e.g. `https://api.example.com`.
    /// - Returns: A configured request, or `nil` if the components are invalid.
    func urlRequest(baseURL: URL) -> URLRequest? {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        return request
    }
}
