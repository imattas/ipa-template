import XCTest
@testable import VisionOSRealityKit

/// Minimal smoke tests for `RealityManager`. These exercise the parts that are
/// independent of an actual RealityKit render target.
@MainActor
final class RealityManagerTests: XCTestCase {

    func testInitialStateIsClosed() {
        let manager = RealityManager()
        XCTAssertEqual(manager.immersiveState, .closed)
        XCTAssertEqual(manager.entityCount, 0)
    }

    func testBuildSceneSeedsEntitiesThenResetClearsThem() async {
        let manager = RealityManager()

        let root = await manager.buildScene()
        XCTAssertEqual(root.name, "Root")
        XCTAssertGreaterThan(manager.entityCount, 0)

        manager.reset()
        XCTAssertEqual(manager.entityCount, 0)
    }
}
