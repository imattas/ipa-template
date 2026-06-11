import XCTest
@testable import SwiftUIKitTemplate

// MARK: - Mock

/// In-memory `APIClientProtocol` used to drive `HomeViewModel` in tests.
final class MockAPIClient: APIClientProtocol, @unchecked Sendable {

    var itemsToReturn: [Item] = []
    var errorToThrow: Error?
    private(set) var fetchItemsCallCount = 0

    func send<T>(_ endpoint: Endpoint) async throws -> T where T: Decodable {
        if let errorToThrow { throw errorToThrow }
        // Not exercised directly by these tests; fetchItems() is the entry point.
        fatalError("send(_:) not stubbed for type \(T.self)")
    }

    func fetchItems() async throws -> [Item] {
        fetchItemsCallCount += 1
        if let errorToThrow { throw errorToThrow }
        return itemsToReturn
    }
}

// MARK: - Tests

@MainActor
final class HomeViewModelTests: XCTestCase {

    func testLoadSuccessPopulatesItemsAndClearsLoading() async {
        let mock = MockAPIClient()
        mock.itemsToReturn = [
            Item(title: "First"),
            Item(title: "Second", subtitle: "with subtitle"),
        ]
        let sut = HomeViewModel(apiClient: mock)

        await sut.load()

        XCTAssertEqual(sut.items.count, 2)
        XCTAssertEqual(sut.items.first?.title, "First")
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(mock.fetchItemsCallCount, 1)
    }

    func testLoadFailureSetsErrorAndClearsItems() async {
        let mock = MockAPIClient()
        mock.errorToThrow = APIError.server(status: 500)
        let sut = HomeViewModel(apiClient: mock)

        await sut.load()

        XCTAssertTrue(sut.items.isEmpty)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertEqual(sut.errorMessage, APIError.server(status: 500).userMessage)
    }

    func testLoadResetsPreviousErrorOnRetry() async {
        let mock = MockAPIClient()
        mock.errorToThrow = APIError.invalidResponse
        let sut = HomeViewModel(apiClient: mock)
        await sut.load()
        XCTAssertNotNil(sut.errorMessage)

        // Second attempt succeeds.
        mock.errorToThrow = nil
        mock.itemsToReturn = [Item(title: "Recovered")]
        await sut.load()

        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(sut.items.count, 1)
    }
}
