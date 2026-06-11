# Module 09 — Testing Your App

A feature isn't done when it works once on your machine — it's done when a test
proves it still works after the next change. In this module you'll write tests
against the real `HomeViewModel` and `APIClient` from the `Swift-SwiftUI`
template, exploit the protocol-based dependency injection you set up in Module 08
to make those tests fast and deterministic, and see how the C and C++ templates
get tested with their own dependency-free harnesses.

The template ships with tests already in place
(`Tests/Unit/HomeViewModelTests.swift`, `Tests/UI/HomeViewTests.swift`). We'll
read them, understand *why* they're shaped the way they are, then extend them.

## What you'll learn

- The testing pyramid and where each kind of test belongs
- Writing unit tests for an `async` `@MainActor` view model with **XCTest**
- How protocol-based DI lets you inject a `MockAPIClient` with no network
- Testing the error path by configuring the mock to throw an `APIError`
- The newer **Swift Testing** framework (`import Testing`, `@Test`, `#expect`) as
  an alternative to XCTest
- **UI testing** with XCUITest: launching the app and asserting on accessibility
- **Integration-style** tests that mock the network at the `URLSession` layer with
  `URLProtocol`
- How `make test` covers the **C and C++** templates
- Running tests from Xcode (Cmd+U) and the command line (`xcodebuild test`)

## Prerequisites

- You've completed [Module 08 — Dependency Injection and Architecture](08-dependency-injection-and-architecture.md).
  This module leans directly on the `APIClientProtocol` / `MockAPIClient`
  abstraction introduced there.
- The `Swift-SwiftUI` template open in Xcode 16+, Swift 6 language mode.

---

## 1. The testing pyramid

Not all tests are equal in cost or speed. The classic *testing pyramid* sorts
them by how much they exercise and how fast they run:

```
        /\        UI / end-to-end       (few, slow, brittle)
       /  \       XCUITest — launches the whole app
      /----\
     /      \     Integration            (some, medium)
    /        \    URLProtocol — real client, fake network
   /----------\
  /            \  Unit                   (many, fast, focused)
 /              \ XCTest / Swift Testing — one type, mocked deps
/________________\
```

The template mirrors this:

| Layer       | Lives in                          | What it touches                                |
|-------------|-----------------------------------|------------------------------------------------|
| Unit        | `Tests/Unit/`                     | `HomeViewModel` with an injected `MockAPIClient` |
| Integration | (you'll add it) `Tests/Integration/` | The real `APIClient` over a fake `URLProtocol` |
| UI          | `Tests/UI/`                       | The whole app via `XCUIApplication`            |

Aim for *many* unit tests, *some* integration tests, and a *few* UI tests. Unit
tests catch most logic bugs in milliseconds; UI tests catch wiring bugs but are
slow and flakier, so keep them thin.

---

## 2. Reading the unit tests that ship with the template

Open `Tests/Unit/HomeViewModelTests.swift`. The whole class is annotated
`@MainActor`, because the thing under test is:

```swift
@Observable
@MainActor
final class HomeViewModel {
    private(set) var items: [Item] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let api: any APIClientProtocol
    init(api: any APIClientProtocol) { self.api = api }

    func load() async { /* ... */ }
}
```

Two things matter for testing:

1. `HomeViewModel` is `@MainActor`, so any code that touches its state must also
   be on the main actor. That's why the test class is `@MainActor` too.
2. The view model depends on `any APIClientProtocol`, **injected through `init`** —
   not a hardcoded `APIClient()`. This is the seam that makes the whole module
   possible.

Here is the success-path test, verbatim from the template:

```swift
// Tests/Unit/HomeViewModelTests.swift
import XCTest
@testable import Swift_SwiftUI

@MainActor
final class HomeViewModelTests: XCTestCase {

    func testLoadSuccessPopulatesItems() async throws {
        // Given a client that returns two items.
        let expected = [
            Item(id: 10, title: "Alpha"),
            Item(id: 20, title: "Beta")
        ]
        let mock = MockAPIClient(items: expected)
        let sut = HomeViewModel(api: mock)

        // When loading.
        await sut.load()

        // Then items are populated and there is no error or in-flight load.
        XCTAssertEqual(sut.items, expected)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }
}
```

Note the anatomy:

- **`func test...() async throws`** — the `async` is what lets you `await
  sut.load()`. XCTest will run the test inside a task and wait for it to finish.
  No expectations, no `wait(for:)`, no semaphores.
- **Given / When / Then** — construct the dependency, exercise one method, assert
  the resulting state.
- **`sut`** is "system under test", a convention that keeps tests readable.
- **`MockAPIClient(items: expected)`** — there is no network. The mock just hands
  back whatever you configured.

### Why the DI from Module 08 makes this work

`MockAPIClient` and the real `APIClient` both conform to `APIClientProtocol`:

```swift
protocol APIClientProtocol: Sendable {
    func send<T: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> T
    func fetchItems() async throws -> [Item]
}
```

Because `HomeViewModel` stores `any APIClientProtocol` rather than the concrete
`actor APIClient`, the test can substitute an in-memory implementation. Without
that protocol seam you'd be forced to hit a live server — slow, flaky, and
impossible to run in CI. *This* is the payoff of the architecture from Module 08.

---

## 3. Testing the error path

The template configures the mock to *throw* and asserts that the view model
surfaces an error message instead of crashing or populating items:

```swift
// Tests/Unit/HomeViewModelTests.swift
func testLoadFailureSetsErrorMessage() async throws {
    // Given a client that throws a server error.
    let mock = MockAPIClient(error: APIError.server(status: 500))
    let sut = HomeViewModel(api: mock)

    // When loading.
    await sut.load()

    // Then no items, an error message, and loading finished.
    XCTAssertTrue(sut.items.isEmpty)
    XCTAssertNotNil(sut.errorMessage)
    XCTAssertFalse(sut.isLoading)
}
```

`MockAPIClient` is built for exactly this — look at its `fetchItems()`:

```swift
func fetchItems() async throws -> [Item] {
    if let error { throw error }
    if delay != .zero { try? await Task.sleep(for: delay) }
    return items
}
```

Set `error` and every call throws it. The view model's `load()` catches it and
converts it into `errorMessage`:

```swift
} catch {
    errorMessage = (error as? APIError)?.errorDescription
        ?? error.localizedDescription
}
```

### Hands-on: assert the *exact* error text

The shipped test only checks that `errorMessage` is non-nil. Tighten it. Add this
test to `HomeViewModelTests`:

```swift
func testServerErrorSurfacesDescription() async throws {
    let mock = MockAPIClient(error: APIError.server(status: 503))
    let sut = HomeViewModel(api: mock)

    await sut.load()

    XCTAssertEqual(
        sut.errorMessage,
        "The server returned an error (status 503)."
    )
}
```

That string comes straight from `APIError.errorDescription` in
`Core/Networking/APIClient.swift`. Because `APIError` is `Equatable` and
`LocalizedError`, you can assert on either the case or its message.

### Hands-on: a `delay` doesn't strand `isLoading`

`MockAPIClient` can simulate latency. Prove the loading flag is reset even when
the call takes time:

```swift
func testLoadingResetsAfterDelay() async throws {
    let mock = MockAPIClient(items: [Item(id: 1, title: "Slow")],
                             delay: .milliseconds(50))
    let sut = HomeViewModel(api: mock)

    await sut.load()

    XCTAssertFalse(sut.isLoading)   // guaranteed by `defer { isLoading = false }`
    XCTAssertEqual(sut.items.count, 1)
}
```

---

## 4. The Swift Testing framework (a modern alternative)

Apple's newer **Swift Testing** framework (Xcode 16+) replaces `XCTAssert*` with a
single `#expect` macro and `@Test` functions. It plays nicely with async/await and
actors and produces far better failure messages. You can adopt it incrementally —
Swift Testing and XCTest can live in the same test target.

Here's the success-path test from step 2, **converted** to Swift Testing. Put it in
a new file `Tests/Unit/HomeViewModelSwiftTests.swift`:

```swift
// Tests/Unit/HomeViewModelSwiftTests.swift
import Testing
@testable import Swift_SwiftUI

@MainActor
struct HomeViewModelSwiftTests {

    @Test
    func loadSuccessPopulatesItems() async throws {
        let expected = [
            Item(id: 10, title: "Alpha"),
            Item(id: 20, title: "Beta")
        ]
        let sut = HomeViewModel(api: MockAPIClient(items: expected))

        await sut.load()

        #expect(sut.items == expected)
        #expect(sut.errorMessage == nil)
        #expect(sut.isLoading == false)
    }

    @Test
    func serverErrorSurfacesDescription() async throws {
        let sut = HomeViewModel(api: MockAPIClient(error: APIError.server(status: 503)))

        await sut.load()

        #expect(sut.errorMessage == "The server returned an error (status 503).")
    }
}
```

What changed:

- `import Testing` instead of `import XCTest`.
- A plain `struct` (not an `XCTestCase` subclass). Each `@Test` runs on a fresh
  instance, so there's less shared-state risk.
- `@Test` marks a test function; the name no longer has to start with `test`.
- `#expect(condition)` replaces every `XCTAssert*`. On failure it prints the
  decomposed expression and the actual values — e.g. it shows you *which* items
  differed, not just "not equal".
- `@MainActor` on the struct still applies, because `HomeViewModel` is main-actor
  isolated.

For a hard requirement that should stop the test immediately, use
`try #require(...)` (the equivalent of `XCTUnwrap` / a fatal assertion). Use
`#expect` for soft checks that should report and continue.

**Which to use?** New tests: prefer Swift Testing. Existing XCTest suites: leave
them — there's no rush, and XCUITest (next section) is still XCTest-only.

---

## 5. UI testing with XCUITest

UI tests launch the *real app* in the simulator and drive it like a user. They
live in `Tests/UI/HomeViewTests.swift` and are always XCTest-based (Swift Testing
doesn't cover UI automation). Here's what ships:

```swift
// Tests/UI/HomeViewTests.swift
import XCTest

final class HomeViewTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testHomeNavigationTitleAppears() throws {
        let app = XCUIApplication()
        app.launch()

        // The Home screen sets navigationTitle("Home").
        let title = app.navigationBars["Home"]
        XCTAssertTrue(
            title.waitForExistence(timeout: 5),
            "Expected the Home navigation bar to appear on launch."
        )
    }
}
```

Key points:

- `XCUIApplication()` is a *handle to a separate process*. You don't `@testable
  import` the app here — you can only observe it through the accessibility tree.
- `app.launch()` cold-starts the app in the simulator.
- `waitForExistence(timeout:)` polls instead of asserting instantly, which is
  essential because the UI renders asynchronously.
- `continueAfterFailure = false` stops a test on the first failed step, so you
  don't chase cascading errors.

### Hands-on: query by accessibility identifier

Matching UI by visible text (`"Home"`) is brittle — it breaks on localization.
The robust approach is a stable **accessibility identifier**. In the SwiftUI view,
tag the list:

```swift
// Features/Home/HomeView.swift  (add the modifier)
List(viewModel.items) { item in
    Text(item.title)
}
.accessibilityIdentifier("home.itemList")
```

Then assert against that identifier in the UI test:

```swift
@MainActor
func testItemListIsVisible() throws {
    let app = XCUIApplication()
    app.launch()

    let list = app.collectionViews["home.itemList"]
        // SwiftUI `List` surfaces as a table or collection view depending on style;
        // use `app.tables["home.itemList"]` if your list renders as a table.
    XCTAssertTrue(list.waitForExistence(timeout: 5))
}
```

Identifiers are invisible to users but stable for tests — prefer them over text
queries for anything you assert on repeatedly.

---

## 6. Integration tests: mock the network with `URLProtocol`

Unit tests mock at the *protocol* layer (`MockAPIClient`). Sometimes you want to
test the **real** `APIClient` — its URL building, status-code handling, and JSON
decoding — without a live server. The standard trick is a custom `URLProtocol`
that intercepts requests inside `URLSession`.

Recall that `APIClient` accepts an injected session:

```swift
actor APIClient: APIClientProtocol {
    init(
        baseURL: URL = URL(string: "https://api.example.com")!,
        session: URLSession = .shared,
        decoder: JSONDecoder = APIClient.makeDecoder()
    ) { /* ... */ }
}
```

That `session:` parameter is the seam. Create `Tests/Integration/StubURLProtocol.swift`:

```swift
// Tests/Integration/StubURLProtocol.swift
import Foundation

/// A URLProtocol that returns canned responses instead of hitting the network.
final class StubURLProtocol: URLProtocol {
    /// (statusCode, body) returned for every intercepted request.
    nonisolated(unsafe) static var stub: (status: Int, data: Data)?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let stub = Self.stub, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: stub.status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
```

> The `nonisolated(unsafe) static var` is a deliberate, scoped escape hatch for
> test stubs only — Swift 6 would otherwise flag the mutable static as a data-race
> risk. Set it before each test on a single thread and you're fine. (You'll learn
> the safe alternatives in [Module 10](10-concurrency-swift6.md).)

Now build a `URLSession` that routes through the stub and feed it to the real
client:

```swift
// Tests/Integration/APIClientIntegrationTests.swift
import XCTest
@testable import Swift_SwiftUI

final class APIClientIntegrationTests: XCTestCase {

    private func makeClient() -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: config)
        return APIClient(
            baseURL: URL(string: "https://api.example.com")!,
            session: session
        )
    }

    func testFetchItemsDecodesJSON() async throws {
        StubURLProtocol.stub = (
            status: 200,
            data: Data(#"[{"id":1,"title":"Alpha"}]"#.utf8)
        )

        let items = try await makeClient().fetchItems()

        XCTAssertEqual(items, [Item(id: 1, title: "Alpha")])
    }

    func testServerErrorMapsToAPIError() async throws {
        StubURLProtocol.stub = (status: 500, data: Data())

        do {
            _ = try await makeClient().fetchItems()
            XCTFail("Expected APIError.server to be thrown")
        } catch let error as APIError {
            XCTAssertEqual(error, .server(status: 500))
        }
    }
}
```

This exercises code the unit tests *can't*: `Endpoint.urlRequest(baseURL:)`, the
`(200..<300).contains` status check, and `JSONDecoder` with snake-case
conversion — all without a network. That's the sweet spot of an integration test.

---

## 7. How `make test` covers the C and C++ templates

The Apple-platform templates use XCTest/Swift Testing, but the `C-Library` and
`CPlusPlus-Framework` templates have **no external test framework at all** — they
ship a tiny dependency-free harness driven by `make test`. CI runs exactly this.

In `templates/C-Library`, the `Makefile` auto-discovers every `tests/test_*.c`,
links each against the static library, and runs them:

```make
TEST_SRCS = $(wildcard tests/test_*.c)
TEST_BINS = $(patsubst tests/%.c,$(BUILD)/%,$(TEST_SRCS))

test: $(TEST_BINS)
	@fail=0; \
	for t in $(TEST_BINS); do \
		echo "==> $$t"; \
		$$t || fail=1; \
	done; \
	exit $$fail
```

A test is just a C program that returns non-zero on failure. The harness is a few
`CHECK` macros in `tests/test_util.h`:

```c
// tests/test_dyn_array.c
#include "util.h"
#include "test_util.h"

static int test_push_and_grow(void) {
    util_dyn_array arr;
    CHECK(util_dyn_array_init(&arr, sizeof(int), NULL) == UTIL_OK);
    for (int i = 0; i < 100; ++i) {
        CHECK(util_dyn_array_push(&arr, &i) == UTIL_OK);
    }
    CHECK_EQ_INT(util_dyn_array_count(&arr), 100);
    util_dyn_array_destroy(&arr);
    return 0;
}
```

The C++ template (`CPlusPlus-Framework/Makefile`) is identical in spirit, just
with `tests/test_*.cpp` and `$(CXX)`. Run them from the template directory:

```bash
cd templates/C-Library        && make test
cd templates/CPlusPlus-Framework && make test
```

You can crank up rigor with sanitizers, since the Makefiles let you override
flags:

```bash
make CXXFLAGS_EXTRA="-fsanitize=address,undefined" test   # C++ template
```

The lesson: a "test framework" can be as small as *a function that returns 0 for
pass*. The same pyramid applies — these are unit tests for the C/C++ libraries.

---

## 8. Running the tests

### From Xcode

- **Cmd+U** runs every test in the scheme (unit, integration, and UI).
- Click the diamond ◇ in the gutter next to a single test to run just that one.
- The **Test navigator** (Cmd+6) lists results; failures jump to the failing
  assertion.

### From the command line

For the Swift app, point `xcodebuild` at your scheme and a simulator:

```bash
xcodebuild test \
  -scheme Swift-SwiftUI \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

To run only the fast unit tests (skip the slow UI suite):

```bash
xcodebuild test \
  -scheme Swift-SwiftUI \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:Swift-SwiftUITests/HomeViewModelTests
```

For the C and C++ templates there's no Xcode project — just `make test` as shown
above. This is precisely what runs green in CI for all ten templates.

---

## Try it yourself

1. Add a `testEmptyResponse()` unit test: configure `MockAPIClient(items: [])`,
   call `load()`, and assert `items.isEmpty`, `errorMessage == nil`,
   `isLoading == false`.
2. Convert `testLoadFailureSetsErrorMessage` to Swift Testing in
   `HomeViewModelSwiftTests`, using `#expect(sut.items.isEmpty)`.
3. In the integration suite, add a test that stubs a `200` with malformed JSON
   (`Data("{".utf8)`) and asserts the thrown error is `.decoding`. (Hint: `if case
   .decoding = error` since `.decoding` carries an associated string.)
4. Add `.accessibilityIdentifier("home.itemList")` to `HomeView` and write a UI
   test that waits for it.
5. Run `make CFLAGS_EXTRA="-fsanitize=address,undefined" test` in
   `templates/C-Library` and confirm it still passes clean.

## Recap

- The **testing pyramid**: many fast unit tests, some integration tests, a few UI
  tests.
- **Unit tests** for an `async @MainActor` view model use `func test...() async
  throws`, `await sut.load()`, and assert on state — the test class is
  `@MainActor` to match.
- **Protocol-based DI** (Module 08) is what makes mocking possible:
  `HomeViewModel(api: MockAPIClient(...))`.
- **Error paths** are tested by configuring `MockAPIClient(error:)` to throw an
  `APIError`.
- **Swift Testing** (`import Testing`, `@Test`, `#expect`) is the modern
  alternative; adopt it incrementally alongside XCTest.
- **XCUITest** launches the whole app; query by **accessibility identifier** for
  stable assertions.
- **`URLProtocol`** lets you test the real `APIClient` with a fake network for
  integration-style coverage.
- The **C/C++ templates** use a dependency-free harness run by **`make test`** —
  a test is just a program returning 0 on success.
- Run tests with **Cmd+U** in Xcode or **`xcodebuild test`** / **`make test`** on
  the command line.

**Next:** [Module 10 — Concurrency with Swift 6](10-concurrency-swift6.md)
