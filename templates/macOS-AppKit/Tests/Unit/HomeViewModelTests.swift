//
//  HomeViewModelTests.swift
//  macOS-AppKit Template — Unit Tests
//

import XCTest
@testable import macOS_AppKit

@MainActor
final class HomeViewModelTests: XCTestCase {

    // MARK: - Success

    func testLoadItemsPopulatesItemsOnSuccess() async {
        // Given a mock client returning two items.
        let expected = [
            Item(id: 10, title: "Alpha", subtitle: "A"),
            Item(id: 11, title: "Beta", subtitle: nil)
        ]
        let mock = MockAPIClient(stubbedItems: expected)
        let sut = HomeViewModel(apiClient: mock)

        // When loading.
        await sut.loadItems()

        // Then items are populated and there is no error or loading state.
        XCTAssertEqual(sut.items, expected)
        XCTAssertEqual(sut.itemCount, 2)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    // MARK: - Failure

    func testLoadItemsSetsErrorMessageOnFailure() async {
        // Given a mock client that throws a typed API error.
        let mock = MockAPIClient(stubbedError: APIError.unacceptableStatusCode(500))
        let sut = HomeViewModel(apiClient: mock)

        // When loading.
        await sut.loadItems()

        // Then the error is surfaced and items remain empty.
        XCTAssertTrue(sut.items.isEmpty)
        XCTAssertEqual(sut.errorMessage, APIError.unacceptableStatusCode(500).errorDescription)
        XCTAssertFalse(sut.isLoading)
    }

    // MARK: - Bounds

    func testItemAtReturnsNilForOutOfBoundsIndex() async {
        let mock = MockAPIClient(stubbedItems: [Item(id: 1, title: "Only")])
        let sut = HomeViewModel(apiClient: mock)

        await sut.loadItems()

        XCTAssertNotNil(sut.item(at: 0))
        XCTAssertNil(sut.item(at: 99))
    }
}
