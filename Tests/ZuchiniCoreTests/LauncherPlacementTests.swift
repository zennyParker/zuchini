import XCTest
@testable import ZuchiniCore

final class LauncherPlacementTests: XCTestCase {
    func testDragClampsAtEachEdge() {
        var placement = LauncherPlacement()
        placement.move(x: -100, y: 1000, width: 800, height: 350)
        XCTAssertEqual(placement.center(width: 800, height: 350).x, 30)
        XCTAssertEqual(placement.center(width: 800, height: 350).y, 320)
        placement.move(x: 1000, y: -100, width: 800, height: 350)
        XCTAssertEqual(placement.center(width: 800, height: 350).x, 770)
        XCTAssertEqual(placement.center(width: 800, height: 350).y, 30)
    }

    func testRotationPreservesRelativePlacement() {
        var placement = LauncherPlacement()
        placement.move(x: 200, y: 400, width: 400, height: 800)
        XCTAssertEqual(placement.center(width: 800, height: 400).x, 400)
        XCTAssertEqual(placement.center(width: 800, height: 400).y, 200)
    }

    func testTinyViewportAndInvalidInputStayFinite() {
        var placement = LauncherPlacement()
        placement.move(x: .nan, y: 5, width: 400, height: 800)
        XCTAssertEqual(placement.horizontal, 1)
        XCTAssertEqual(placement.center(width: 20, height: 0).x, 10)
        XCTAssertEqual(placement.center(width: 20, height: 0).y, 0)
        XCTAssertEqual(placement.center(width: .infinity, height: .nan).x, 0)
    }
}
