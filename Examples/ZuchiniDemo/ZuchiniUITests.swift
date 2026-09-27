import XCTest

final class ZuchiniUITests: XCTestCase {
    func testDragReopenAndRotation() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        let close = app.buttons["zuchini.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        let panel = app.otherElements["AIMBOT menu"].firstMatch
        XCTAssertGreaterThan(panel.frame.width, 0)
        XCTAssertLessThanOrEqual(panel.frame.width, 401)
        XCTAssertLessThanOrEqual(panel.frame.height, 361)
        close.tap()
        let launcher = app.buttons["zuchini.launcher"]
        XCTAssertTrue(launcher.waitForExistence(timeout: 3))
        let initial = launcher.frame
        let destination = app.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.65))
        launcher.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: destination)
        XCTAssertFalse(close.exists, "Dragging must not open the menu")
        XCTAssertGreaterThan(abs(launcher.frame.midY - initial.midY), 80)
        XCTAssertGreaterThan(abs(launcher.frame.midX - initial.midX), 40)
        let moved = launcher.frame
        launcher.tap()
        XCTAssertTrue(close.waitForExistence(timeout: 3))
        close.tap()
        XCTAssertTrue(launcher.waitForExistence(timeout: 3))
        XCTAssertEqual(launcher.frame.midX, moved.midX, accuracy: 2)
        XCTAssertEqual(launcher.frame.midY, moved.midY, accuracy: 2)
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(launcher.waitForExistence(timeout: 3))
        XCTAssertTrue(app.frame.insetBy(dx: -1, dy: -1).contains(launcher.frame))
        launcher.tap()
        XCTAssertTrue(close.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["zuchini.control.aimbot.target"].isHittable)
        app.buttons["zuchini.control.aimbot.target"].tap()
        let head = app.buttons["zuchini.option.aimbot.target.Head"]
        if !head.isHittable { app.swipeUp() }
        XCTAssertTrue(head.isHittable)
        head.tap()
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Compact menu landscape"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
