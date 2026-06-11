import XCTest
@testable import watchOS_SwiftUI

@MainActor
final class HomeViewModelTests: XCTestCase {

    func testLoadSuccessPopulatesItems() async {
        // Given a client that returns a known set of items.
        let expected = MockAPIClient.sampleItems
        let mock = MockAPIClient(result: .success(expected))
        let sut = HomeViewModel(apiClient: mock)

        // When loading.
        await sut.load()

        // Then items are populated and there is no error or loading state.
        XCTAssertEqual(sut.items, expected)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    func testLoadFailureSurfacesErrorMessage() async {
        // Given a client that fails with a typed error.
        let mock = MockAPIClient(result: .failure(APIError.statusCode(500)))
        let sut = HomeViewModel(apiClient: mock)

        // When loading.
        await sut.load()

        // Then the error message is surfaced and items remain empty.
        XCTAssertTrue(sut.items.isEmpty)
        XCTAssertEqual(sut.errorMessage, APIError.statusCode(500).localizedDescription)
        XCTAssertFalse(sut.isLoading)
    }

    func testInitialStateIsEmpty() {
        let sut = HomeViewModel(apiClient: MockAPIClient())
        XCTAssertTrue(sut.items.isEmpty)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }
}
