//
//  HomeViewModelTests.swift
//  Swift-SwiftUI
//
//  Unit tests for HomeViewModel using the injected MockAPIClient.
//

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

    func testLoadStartsEmpty() {
        let sut = HomeViewModel(api: MockAPIClient())
        XCTAssertTrue(sut.items.isEmpty)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }
}
