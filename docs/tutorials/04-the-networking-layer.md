# Module 04 — The Networking Layer: Connecting a Real API

In Module 03 you built your first feature against the in-memory `MockAPIClient`. That was great for getting the UI on screen fast, but a real app talks to a real server. In this module you'll swap the stub for a live REST API, model its JSON, define your own endpoints, handle every failure case, send a `POST` with a body and an auth header, and cancel in-flight requests cleanly.

We'll use [JSONPlaceholder](https://jsonplaceholder.typicode.com) — a free, no-auth, public REST API that returns predictable JSON — so you can run every step without signing up for anything.

**What you'll learn**

- How to point the `actor APIClient` at a real `baseURL`.
- How to model a JSON response with `Codable`, `CodingKeys`, and `keyDecodingStrategy`.
- How to describe requests as value-type `Endpoint`s and how `urlRequest(baseURL:)` turns them into a `URLRequest`.
- How to call the API with the generic `send(_:)` and a typed convenience like `fetchItems()`.
- How to map each `APIError` case to a user-facing `errorMessage` in your view model.
- How to send a `POST` with an `Encodable` body and a bearer-token header.
- How to cancel work using `Task` and the SwiftUI `.task` lifecycle.

**Prerequisites**

- You've completed [Module 03 — Your First Feature](03-your-first-feature.md). You should already have the Home feature rendering items, and you should recognize `APIClientProtocol`, `HomeViewModel`, and `Item`.
- Familiarity with Swift 6 `async`/`await` and actors. We lean on them throughout.

---

## The template you're starting from

The networking layer lives in `templates/Swift-SwiftUI/Core/Networking/`. Three pieces matter here:

- `Endpoint.swift` — a `struct Endpoint` plus `enum HTTPMethod`, and a `urlRequest(baseURL:)` builder.
- `APIClient.swift` — the `Item` model, the typed `APIError` enum, the `APIClientProtocol`, the live `actor APIClient`, and the `MockAPIClient`.

For reference, the protocol every client conforms to is:

```swift
protocol APIClientProtocol: Sendable {
    /// Sends an endpoint and decodes the response body into `T`.
    func send<T: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> T

    /// Concrete convenience for the home feature.
    func fetchItems() async throws -> [Item]
}
```

Everything below either configures or extends these files. We never change the call sites in the views — that's the payoff of protocol-based dependency injection.

---

## Step 1 — Configure the base URL

Open `templates/Swift-SwiftUI/Core/Networking/APIClient.swift`. The live client's initializer currently points at a placeholder:

```swift
// In APIClient.swift — BEFORE
init(
    baseURL: URL = URL(string: "https://api.example.com")!, // TODO: configure
    session: URLSession = .shared,
    decoder: JSONDecoder = APIClient.makeDecoder()
) {
    self.baseURL = baseURL
    self.session = session
    self.decoder = decoder
}
```

Point it at JSONPlaceholder:

```swift
// In APIClient.swift — AFTER
init(
    baseURL: URL = URL(string: "https://jsonplaceholder.typicode.com")!,
    session: URLSession = .shared,
    decoder: JSONDecoder = APIClient.makeDecoder()
) {
    self.baseURL = baseURL
    self.session = session
    self.decoder = decoder
}
```

A couple of notes:

- The base URL has **no trailing slash** and **no path**. Paths come from the `Endpoint` (Step 3), and `urlRequest(baseURL:)` joins them with `appendingPathComponent`.
- Don't hard-code secrets here. For real apps, inject the URL from your build configuration (`Info.plist`, an `.xcconfig`, or an environment value) and pass it into `APIClient(baseURL:)`. Because the URL is a parameter, tests and previews can override it freely.

> Force-unwrapping a literal URL with `!` is acceptable for a constant you control. Never force-unwrap a URL built from user input — return `APIError.invalidURL` instead, which is exactly what `urlRequest(baseURL:)` already does.

---

## Step 2 — Model the response with Codable

JSONPlaceholder's `/posts` endpoint returns an array of objects shaped like this:

```json
[
  {
    "userId": 1,
    "id": 1,
    "title": "sunt aut facere repellat provident",
    "body": "quia et suscipit\nsuscipit recusandae"
  }
]
```

The template's `Item` already matches *most* of this — it has an `id: Int` and a `title: String` — but its third field is `subtitle`, and the JSON calls it `body`. There are two clean ways to reconcile that. Pick whichever you prefer; both keep the rest of the app unchanged because the property names stay `id`, `title`, `subtitle`.

### Option A — Map with `CodingKeys`

Edit `Item` in `APIClient.swift` so the decoder maps the JSON `body` field onto the `subtitle` property:

```swift
// In APIClient.swift — Item modeled against /posts JSON
struct Item: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let subtitle: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle = "body"   // JSON "body" -> Swift "subtitle"
    }

    init(id: Int, title: String, subtitle: String? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
    }
}
```

`CodingKeys` only lists the fields you care about — `userId` is simply ignored on decode, which is the behavior you want.

### Option B — Rely on `keyDecodingStrategy`

The live client already builds its decoder like this:

```swift
private static func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return decoder
}
```

`.convertFromSnakeCase` turns JSON keys like `user_id` into Swift `userId` automatically, so you never write `CodingKeys` just for snake_case naming. JSONPlaceholder happens to use `camelCase` (`userId`) already, so this strategy is a no-op here — but keep it, because most real APIs are snake_case. When a single field's name genuinely differs (like `body` vs `subtitle`), reach for `CodingKeys` as in Option A. The two compose: `keyDecodingStrategy` handles the bulk, `CodingKeys` handles the exceptions.

> If you'd rather model the API faithfully and map into your domain later, create a separate `struct PostDTO: Decodable { let userId: Int; let id: Int; let title: String; let body: String }` and add an `Item(from:)` initializer. That keeps your domain model independent of the wire format. For this tutorial we keep one type to stay focused.

We'll use **Option A** for the rest of the module.

---

## Step 3 — Define your endpoints

Open `Endpoint.swift`. Recall the shape of the type and its request builder:

```swift
struct Endpoint: Sendable {
    var path: String
    var method: HTTPMethod        // .get / .post / .put / .patch / .delete
    var query: [String: String]
    var headers: [String: String]
    var body: Data?

    func urlRequest(baseURL: URL) throws -> URLRequest { ... }
}
```

`urlRequest(baseURL:)` does the assembly for you:

1. Appends `path` to `baseURL` (`https://jsonplaceholder.typicode.com` + `/posts`).
2. Adds sorted `query` items as `URLQueryItem`s, if any.
3. Sets `httpMethod` and `httpBody`.
4. Sets `Accept: application/json`, plus `Content-Type: application/json` when there's a body.
5. Applies your custom `headers` last, so they can override the defaults.

The template ships one convenience factory:

```swift
extension Endpoint {
    static var items: Endpoint {
        Endpoint(path: "/items")
    }
}
```

Update it to hit `/posts`, and add a parameterized factory for a single post:

```swift
// In Endpoint.swift — extend the convenience factories
extension Endpoint {
    /// Fetches the list of posts (used by the Home feature).
    static let posts = Endpoint(path: "/posts")

    /// Fetches a single post by id, e.g. /posts/42.
    static func post(id: Int) -> Endpoint {
        Endpoint(path: "/posts/\(id)")
    }

    /// Fetches posts authored by a given user via a query parameter,
    /// e.g. /posts?userId=1.
    static func posts(byUser userId: Int) -> Endpoint {
        Endpoint(path: "/posts", query: ["userId": String(userId)])
    }
}
```

Use a `static let` for endpoints with no parameters and a `static func` factory when something varies. The `query` dictionary turns into `?userId=1`; you never hand-build query strings.

---

## Step 4 — Call it with `send(_:)` and a typed fetch

The generic `send(_:)` does the heavy lifting — request building, transport, status checking, and decoding — and infers the result type from the call site:

```swift
// Decodes into [Item] because that's what the caller expects.
let posts: [Item] = try await client.send(.posts)

// Decodes into a single Item.
let one: Item = try await client.send(.post(id: 1))
```

Now wire the Home feature's convenience method to the new endpoint. In `APIClient.swift`:

```swift
// In APIClient.swift — BEFORE
func fetchItems() async throws -> [Item] {
    try await send(.items)
}
```

```swift
// In APIClient.swift — AFTER
func fetchItems() async throws -> [Item] {
    try await send(.posts)
}
```

That's the only change to the live client's request logic. `HomeViewModel.load()` already calls `api.fetchItems()`, so the Home screen now shows real posts from the network with no edits to the view model or the view.

---

## Step 5 — Handle every APIError case in the view model

`send(_:)` throws a typed `APIError`. Here's how each case arises:

| Case | When it's thrown |
| --- | --- |
| `.invalidURL` | `urlRequest(baseURL:)` couldn't form a valid URL from the path/query. |
| `.requestFailed(URLError)` | The transport failed — offline, DNS, timeout, TLS. Wraps the underlying `URLError`. |
| `.invalidResponse` | The response wasn't an `HTTPURLResponse`. |
| `.server(status:)` | An HTTP status outside `200..<300` (e.g. 404, 500). |
| `.decoding(String)` | The body didn't match your `Decodable` type. |

The current `HomeViewModel.load()` already surfaces these well, because `APIError` is `LocalizedError`:

```swift
// HomeViewModel.load() — as shipped
do {
    items = try await api.fetchItems()
} catch is CancellationError {
    // Ignore cancellations (e.g. view dismissed mid-load).
} catch {
    errorMessage = (error as? APIError)?.errorDescription
        ?? error.localizedDescription
}
```

If you want different UI per case — say, a "Retry" button only for transport failures, or a sign-in prompt on `401` — switch on the typed error explicitly. Note the property is `api`, not `apiClient`:

```swift
// In HomeViewModel.swift — case-by-case handling (optional refinement)
func load() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
        items = try await api.fetchItems()
    } catch is CancellationError {
        // View dismissed mid-load; nothing to show.
    } catch let APIError.server(status) where status == 401 {
        errorMessage = "Your session expired. Please sign in again."
    } catch let APIError.server(status) {
        errorMessage = "The server returned an error (status \(status))."
    } catch APIError.requestFailed {
        errorMessage = "You appear to be offline. Check your connection and retry."
    } catch let APIError.decoding(detail) {
        // Log `detail` for yourself; show something friendly to the user.
        errorMessage = "We couldn't read the server's response."
        print("Decoding failure: \(detail)")
    } catch {
        errorMessage = (error as? APIError)?.errorDescription
            ?? error.localizedDescription
    }
}
```

Because `APIError` is `Equatable`, you can also assert on exact errors in unit tests — e.g. inject `MockAPIClient(error: APIError.server(status: 500))` and check that `errorMessage` reflects it.

---

## Step 6 — Send a POST with a body and a bearer token

`send(_:)` is generic over the *response*, and `Endpoint` carries an optional `body: Data?`, so creating data is just as easy as reading it. JSONPlaceholder accepts `POST /posts` and echoes back the created object with a new `id`.

First, model the request payload as an `Encodable` type. Add it to `Endpoint.swift` (or a feature file):

```swift
// In Endpoint.swift — request payload
struct NewPost: Encodable, Sendable {
    let title: String
    let body: String
    let userId: Int
}
```

Then add a factory that encodes the payload into the endpoint's `body` and attaches an `Authorization` header. JSON encoding can throw, so make the factory `throws`:

```swift
// In Endpoint.swift — a POST factory with body + auth header
extension Endpoint {
    static func createPost(_ post: NewPost, token: String) throws -> Endpoint {
        Endpoint(
            path: "/posts",
            method: .post,
            headers: ["Authorization": "Bearer \(token)"],
            body: try JSONEncoder().encode(post)
        )
    }
}
```

`urlRequest(baseURL:)` automatically sets `Content-Type: application/json` whenever `body != nil`, and your `Authorization` header is applied after the defaults, so it always wins. Call it from a view model method:

```swift
// In a view model — creating a post
func submit(title: String, body: String) async {
    do {
        let payload = NewPost(title: title, body: body, userId: 1)
        let endpoint = try Endpoint.createPost(payload, token: authToken)
        let created: Item = try await api.send(endpoint)
        items.insert(created, at: 0)
    } catch {
        errorMessage = (error as? APIError)?.errorDescription
            ?? error.localizedDescription
    }
}
```

> Adding `send` for arbitrary endpoints to `APIClientProtocol`? It's already there — `send<T: Decodable & Sendable>(_:)` handles any endpoint and any `Decodable` response. The protocol only special-cases `fetchItems()` for convenience. If you mock a `POST` in tests, remember `MockAPIClient.send` returns its configured `items` for the items case; extend it to recognize your new endpoints by inspecting `endpoint.path` and `endpoint.method`.

Real auth tokens should come from a keychain-backed store, not a hard-coded constant. Inject the token into your view model the same way you inject `api`.

---

## Step 7 — Cancellation with Task and `.task`

Network calls can outlive the screen that started them. Swift Concurrency cooperatively cancels: when a `Task` is cancelled, the `await` on `URLSession.data(for:)` throws, and `HomeViewModel.load()` already catches `CancellationError` and quietly stops. You get this for free in two situations.

**SwiftUI `.task`** — the modifier ties a task to the view's lifetime and cancels it automatically when the view disappears:

```swift
// In HomeView.swift
.task {
    await viewModel.load()
}
```

If you bind the task to a value, SwiftUI cancels and restarts it whenever that value changes — perfect for reloading when a filter changes:

```swift
.task(id: selectedUserId) {
    await viewModel.load(userId: selectedUserId)
}
```

**Manual `Task`** — when you start work outside the view lifecycle (e.g. from a button), hold the handle so you can cancel it:

```swift
// In a view model — manual cancellation
private var loadTask: Task<Void, Never>?

func reload() {
    loadTask?.cancel()           // cancel any in-flight load first
    loadTask = Task { await load() }
}
```

Because `HomeViewModel` is `@MainActor`, mutating `loadTask` and reading state from inside the task is automatically isolated to the main actor — no data races, no manual locking. If you need to bail out early in a long loop, check `try Task.checkCancellation()` (which throws `CancellationError`) or `Task.isCancelled` between units of work.

---

## Try it yourself

1. **List a user's posts.** Add `func load(userId: Int)` to `HomeViewModel` that calls `api.send(.posts(byUser: userId))` and renders only that user's posts. Drive it from `.task(id:)`.
2. **Pull-to-refresh.** Add `.refreshable { await viewModel.load() }` to the `List` in `HomeView`. Because `load()` is idempotent, no other change is needed.
3. **Force each error.** In a preview, inject `MockAPIClient(error: APIError.server(status: 404))`, then `.requestFailed(URLError(.notConnectedToInternet))`, then `.decoding("...")`, and confirm `errorMessage` reads correctly for each.
4. **Real decode failure.** Temporarily point `fetchItems()` at `.post(id: 1)` (a single object) while still decoding `[Item]`. Watch `.decoding` fire, then fix it. This builds intuition for mismatch errors.
5. **Round-trip a POST.** Wire up Step 6's `submit(title:body:)` to a small form and confirm the created `Item` appears at the top of your list.

## Recap

- You pointed the `actor APIClient` at a real `baseURL` — passed in, never hard-coded, so it's overridable in tests.
- You modeled the response by editing `Item`'s `Codable`, using `CodingKeys` to map `body` -> `subtitle` and `keyDecodingStrategy` for snake_case keys.
- You described requests as value-type `Endpoint`s and let `urlRequest(baseURL:)` build the `URLRequest` — paths, query items, headers, and JSON defaults.
- You called the API through the generic `send(_:)` and the typed `fetchItems()`, changing one line to go live with zero view changes.
- You mapped each `APIError` case to a user-facing message, leaning on `LocalizedError` and `Equatable`.
- You sent a `POST` with an `Encodable` body and a bearer-token header.
- You cancelled in-flight work via `.task`, `.task(id:)`, and a held `Task` handle — with `load()` swallowing `CancellationError`.

**Next:** [Module 05 — State & Data Flow](05-state-and-data-flow.md)
