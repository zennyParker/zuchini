#if canImport(SwiftUI)
import XCTest
import ZuchiniCore
import ZuchiniMenu

final class AimingControllerTests: XCTestCase {
    func testDisabledAndSuspendedControllerNeverQueriesOrWritesHost() async throws {
        try await MainActor.run {
            let store = MenuStore(definition: try AimbotMenu.definition())
            let host = FakeAimingHost()
            let controller = AimingController(store: store, host: host)
            XCTAssertEqual(controller.step(at: 0).status, .inactive)
            controller.activate()
            XCTAssertEqual(controller.step(at: 0).status, .disabled)
            XCTAssertEqual(host.reads, 0)
            XCTAssertEqual(host.writes, 0)
            store.set(.toggle(true), for: "aimbot.enabled")
            host.frame = sampleFrame(1, at: 0)
            XCTAssertEqual(controller.step(at: 0).status, .priming)
            host.frame = sampleFrame(2, at: 0.02)
            XCTAssertEqual(controller.step(at: 0.02).status, .tracking)
            XCTAssertEqual(host.writes, 1)
            store.set(.toggle(false), for: "aimbot.enabled")
            XCTAssertEqual(controller.step(at: 0.04).status, .disabled)
            XCTAssertEqual(host.reads, 2)
            XCTAssertEqual(host.writes, 1)
            controller.suspend()
            XCTAssertEqual(controller.step(at: 0.06).status, .inactive)
        }
    }

    func testHostRejectionAndMenuChangesPreventStaleWrites() async throws {
        try await MainActor.run {
            let store = MenuStore(definition: try AimbotMenu.definition())
            store.set(.toggle(true), for: "aimbot.enabled")
            let host = FakeAimingHost()
            let controller = AimingController(store: store, host: host)
            controller.activate()
            host.frame = sampleFrame(1, at: 0)
            _ = controller.step(at: 0)
            host.frame = sampleFrame(2, at: 0.02)
            host.onCapture = { store.set(.toggle(false), for: "aimbot.enabled") }
            XCTAssertEqual(controller.step(at: 0.02).status, .interrupted)
            XCTAssertEqual(host.writes, 0)
            host.onCapture = nil
            store.set(.toggle(true), for: "aimbot.enabled")
            host.frame = sampleFrame(3, at: 0.04)
            XCTAssertEqual(controller.step(at: 0.04).status, .priming)
            host.acceptWrites = false
            host.frame = sampleFrame(4, at: 0.06)
            XCTAssertEqual(controller.step(at: 0.06).status, .invalidFrame)
            host.frame = sampleFrame(5, at: 0.08)
            XCTAssertEqual(controller.step(at: 0.08).status, .priming)
        }
    }

    func testSuspensionDuringCaptureAndHostReleaseAreSafe() async throws {
        try await MainActor.run {
            let store = MenuStore(definition: try AimbotMenu.definition())
            store.set(.toggle(true), for: "aimbot.enabled")
            var host: FakeAimingHost? = FakeAimingHost()
            let controller = AimingController(store: store, host: host!)
            controller.activate()
            host?.frame = sampleFrame(1, at: 0)
            host?.onCapture = { controller.suspend() }
            XCTAssertEqual(controller.step(at: 0).status, .inactive)
            XCTAssertEqual(host?.writes, 0)
            host = nil
            controller.activate()
            XCTAssertEqual(controller.step(at: 0.02).status, .inactive)
        }
    }
}

@MainActor
private final class FakeAimingHost: AimingHost {
    var frame: AimFrame?
    var reads = 0
    var writes = 0
    var acceptWrites = true
    var onCapture: (() -> Void)?
    func captureAimFrame() -> AimFrame? { reads += 1; onCapture?(); return frame }
    func applyAimCommand(_ command: AimCommand) -> Bool { writes += 1; return acceptWrites }
}

private func sampleFrame(_ sequence: UInt64, at time: Double) -> AimFrame {
    AimFrame(sequence: sequence, capturedAt: time, cameraOrigin: AimVector(0, 0, 0),
             cameraForward: AimVector(0, 0, 1), candidates: [
                AimCandidate(id: "enemy", head: AimVector(0.2, 0.1, 1), neck: AimVector(0.2, 0, 1),
                             isEnemy: true, isAlive: true, isVisible: true)
             ])
}
#endif
