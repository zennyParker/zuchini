import XCTest
@testable import ZuchiniCore

final class AimingEngineTests: XCTestCase {
    private let forward = AimVector(0, 0, 1)
    private let enabled = AimSettings(enabled: true, targetPoint: .head, fovDegrees: 60)

    private func direction(_ degrees: Double) -> AimVector {
        let angle = degrees * Double.pi / 180
        return AimVector(sin(angle), 0, cos(angle))
    }

    private func target(_ id: String = "enemy", degrees: Double = 20,
                        visible: Bool = true, alive: Bool = true, enemy: Bool = true) -> AimCandidate {
        AimCandidate(id: id, head: direction(degrees), neck: direction(degrees / 2),
                     isEnemy: enemy, isAlive: alive, isVisible: visible)
    }

    private func frame(_ sequence: UInt64, at time: Double, candidates: [AimCandidate],
                       forward: AimVector? = nil) -> AimFrame {
        AimFrame(sequence: sequence, capturedAt: time, cameraOrigin: AimVector(0, 0, 0),
                 cameraForward: forward ?? self.forward, candidates: candidates)
    }

    private func tracked(_ candidates: [AimCandidate], settings: AimSettings? = nil) throws -> AimCommand {
        var engine = AimingEngine()
        _ = engine.update(frame: frame(1, at: 0, candidates: candidates), settings: settings ?? enabled, at: 0)
        return try XCTUnwrap(engine.update(frame: frame(2, at: 0.02, candidates: candidates),
                                           settings: settings ?? enabled, at: 0.02).command)
    }

    func testHeadAndNeckUseDistinctPositions() throws {
        let head = try tracked([target()])
        let neck = try tracked([target()], settings: AimSettings(enabled: true, targetPoint: .neck, fovDegrees: 60))
        XCTAssertEqual(head.targetPoint, .head)
        XCTAssertEqual(neck.targetPoint, .neck)
        XCTAssertGreaterThan(try XCTUnwrap(forward.angleDegrees(to: head.direction)),
                             try XCTUnwrap(forward.angleDegrees(to: neck.direction)))
    }

    func testDisableImmediatelyStopsAndReenablePrimes() throws {
        var engine = AimingEngine()
        _ = engine.update(frame: frame(1, at: 0, candidates: [target()]), settings: enabled, at: 0)
        let decision = engine.update(frame: frame(2, at: 0.02, candidates: [target()]),
                                     settings: AimSettings(enabled: false, targetPoint: .head, fovDegrees: 60), at: 0.02)
        XCTAssertEqual(decision.status, .disabled)
        XCTAssertNil(decision.command)
        XCTAssertNil(engine.lockedTargetID)
        XCTAssertEqual(engine.update(frame: frame(3, at: 0.04, candidates: [target()]),
                                     settings: enabled, at: 0.04).status, .priming)
    }

    func testFOVIsFullConeAndRejectsBehindCamera() throws {
        let result = try tracked([target("outside", degrees: 30.01), target("edge", degrees: 30), target("behind", degrees: 179)])
        XCTAssertEqual(result.targetID, "edge")
        var engine = AimingEngine()
        let decision = engine.update(frame: frame(1, at: 0, candidates: [target(degrees: 31)]), settings: enabled, at: 0)
        XCTAssertEqual(decision.status, .noTarget)
        XCTAssertNil(decision.command)
    }

    func testFiltersAlliesDeadHiddenMissingAndInvalidBones() throws {
        let missing = AimCandidate(id: "missing", head: nil, neck: direction(0), isEnemy: true, isAlive: true, isVisible: true)
        let invalid = AimCandidate(id: "invalid", head: AimVector(.nan, 0, 1), neck: nil, isEnemy: true, isAlive: true, isVisible: true)
        let coincident = AimCandidate(id: "coincident", head: AimVector(0, 0, 0), neck: nil, isEnemy: true, isAlive: true, isVisible: true)
        let result = try tracked([target("ally", degrees: 0, enemy: false), target("dead", degrees: 0, alive: false),
                                  target("hidden", degrees: 0, visible: false), missing, invalid, coincident, target("valid")])
        XCTAssertEqual(result.targetID, "valid")
    }

    func testDuplicatesExcludedAndTiesIndependentOfInputOrder() throws {
        let candidates = [target("dup", degrees: 0), target("dup", degrees: 1), target("b", degrees: 10), target("a", degrees: -10)]
        XCTAssertEqual(try tracked(candidates).targetID, "a")
        XCTAssertEqual(try tracked(candidates.reversed()).targetID, "a")
    }

    func testRetentionAvoidsSmallTargetSwitchesButReleasesInvalidTarget() {
        var engine = AimingEngine()
        _ = engine.update(frame: frame(1, at: 0, candidates: [target("a", degrees: 10)]), settings: enabled, at: 0)
        let retained = engine.update(frame: frame(2, at: 0.02, candidates: [target("a", degrees: 10), target("b", degrees: 8)]), settings: enabled, at: 0.02)
        XCTAssertEqual(retained.command?.targetID, "a")
        let switched = engine.update(frame: frame(3, at: 0.04, candidates: [target("a", degrees: 10), target("b", degrees: 6)]), settings: enabled, at: 0.04)
        XCTAssertEqual(switched.command?.targetID, "b")
        let hidden = engine.update(frame: frame(4, at: 0.06, candidates: [target("a", degrees: 10), target("b", degrees: 6, visible: false)]), settings: enabled, at: 0.06)
        XCTAssertEqual(hidden.command?.targetID, "a")
    }

    func testTargetLossStopsInsteadOfReusingPreviousCommand() {
        var engine = AimingEngine()
        _ = engine.update(frame: frame(1, at: 0, candidates: [target()]), settings: enabled, at: 0)
        let lost = engine.update(frame: frame(2, at: 0.02, candidates: []), settings: enabled, at: 0.02)
        XCTAssertEqual(lost.status, .noTarget)
        XCTAssertNil(lost.command)
        XCTAssertNil(engine.lockedTargetID)
    }

    func testLiveFOVChangeDropsLockAndPointChangeUsesNewBone() throws {
        var engine = AimingEngine()
        let candidates = [target(degrees: 20)]
        _ = engine.update(frame: frame(1, at: 0, candidates: candidates), settings: enabled, at: 0)
        let narrow = AimSettings(enabled: true, targetPoint: .head, fovDegrees: 10)
        XCTAssertEqual(engine.update(frame: frame(2, at: 0.02, candidates: candidates), settings: narrow, at: 0.02).status, .noTarget)
        XCTAssertNil(engine.lockedTargetID)
        let neck = AimSettings(enabled: true, targetPoint: .neck, fovDegrees: 60)
        let result = try XCTUnwrap(engine.update(frame: frame(3, at: 0.04, candidates: candidates), settings: neck, at: 0.04).command)
        XCTAssertEqual(result.targetPoint, .neck)
        XCTAssertLessThan(try XCTUnwrap(forward.angleDegrees(to: result.direction)), 10)
    }

    func testStaleRepeatedOutOfOrderAndFutureFramesDoNotProduceCommands() {
        var engine = AimingEngine()
        let initial = frame(10, at: 1, candidates: [target()])
        _ = engine.update(frame: initial, settings: enabled, at: 1)
        XCTAssertEqual(engine.update(frame: initial, settings: enabled, at: 1.02).status, .waitingForFrame)
        XCTAssertEqual(engine.update(frame: frame(9, at: 1.03, candidates: [target()]), settings: enabled, at: 1.03).status, .invalidFrame)
        XCTAssertEqual(engine.update(frame: initial, settings: enabled, at: 2).status, .staleFrame)
        XCTAssertEqual(engine.update(frame: frame(11, at: 3, candidates: [target()]), settings: enabled, at: 2).status, .invalidFrame)
    }

    func testPauseAndResetNeverCauseCatchUpSnap() {
        var engine = AimingEngine()
        _ = engine.update(frame: frame(1, at: 0, candidates: [target()]), settings: enabled, at: 0)
        let resumed = engine.update(frame: frame(2, at: 1, candidates: [target()]), settings: enabled, at: 1)
        XCTAssertEqual(resumed.status, .interrupted)
        XCTAssertNil(resumed.command)
        engine.reset()
        XCTAssertEqual(engine.update(frame: frame(1, at: 1.02, candidates: [target()]), settings: enabled, at: 1.02).status, .priming)
    }

    func testInvalidCameraClockSettingsAndOversizedFrameAreRejected() {
        var engine = AimingEngine()
        for camera in [AimVector(0, 0, 0), AimVector(.nan, 0, 1), AimVector(0, .infinity, 1)] {
            XCTAssertEqual(engine.update(frame: frame(1, at: 0, candidates: [target()], forward: camera), settings: enabled, at: 0).status, .invalidFrame)
        }
        for fov in [Double.nan, .infinity, -1, 0, 181] {
            XCTAssertEqual(engine.update(frame: frame(1, at: 0, candidates: [target()]),
                                         settings: AimSettings(enabled: true, targetPoint: .head, fovDegrees: fov), at: 0).status, .invalidSettings)
        }
        XCTAssertEqual(engine.update(frame: nil, settings: enabled, at: 0).status, .invalidFrame)
        XCTAssertEqual(engine.update(frame: frame(1, at: 0, candidates: []), settings: enabled, at: .nan).status, .invalidFrame)
        XCTAssertEqual(engine.update(frame: frame(1, at: 0, candidates: Array(repeating: target(), count: 1025)), settings: enabled, at: 0).status, .invalidFrame)
    }

    func testSmoothingHasNoOvershootAndIsConsistentAcrossFrameRates() throws {
        let destination = direction(60)
        let settings = AimSettings(enabled: true, targetPoint: .head, fovDegrees: 180)
        var endpoints: [AimVector] = []
        for fps in [30, 60, 120] {
            var engine = AimingEngine()
            var camera = forward
            _ = engine.update(frame: frame(1, at: 0, candidates: [target(degrees: 60)]), settings: settings, at: 0)
            var previousError = 60.0
            for tick in 1...fps {
                let time = Double(tick) / Double(fps)
                let command = try XCTUnwrap(engine.update(frame: frame(UInt64(tick + 1), at: time,
                    candidates: [target(degrees: 60)], forward: camera), settings: settings, at: time).command)
                let movement = try XCTUnwrap(camera.angleDegrees(to: command.direction))
                XCTAssertLessThanOrEqual(movement, 180 / Double(fps) + 1e-7)
                let error = try XCTUnwrap(command.direction.angleDegrees(to: destination))
                XCTAssertLessThanOrEqual(error, previousError + 1e-7)
                XCTAssertLessThanOrEqual(try XCTUnwrap(forward.angleDegrees(to: command.direction)), 60.000001)
                XCTAssertEqual(command.direction.dot(command.direction), 1, accuracy: 1e-12)
                camera = command.direction; previousError = error
            }
            XCTAssertLessThan(previousError, 0.1)
            endpoints.append(camera)
        }
        XCTAssertEqual(endpoints[0].x, endpoints[1].x, accuracy: 1e-9)
        XCTAssertEqual(endpoints[1].x, endpoints[2].x, accuracy: 1e-9)
    }

    func testMenuSettingsRejectMismatchedSchemaAndUseOnlyThreeControls() throws {
        var state = MenuState(definition: try AimbotMenu.definition())
        XCTAssertEqual(AimSettings(menuState: state), AimSettings(enabled: false, targetPoint: .neck, fovDegrees: 60))
        state.set(.toggle(true), for: "aimbot.enabled")
        state.set(.choice("Head"), for: "aimbot.target")
        state.set(.number(90), for: "aimbot.fov")
        XCTAssertEqual(AimSettings(menuState: state), AimSettings(enabled: true, targetPoint: .head, fovDegrees: 90))
        let unrelated = try MenuDefinition(title: "Other", sections: [MenuSection(id: "s", title: "S", controls: [MenuControl(id: "x", title: "X", kind: .action)])])
        XCTAssertNil(AimSettings(menuState: MenuState(definition: unrelated)))
    }

    func testLongMovingTargetSimulationStaysFiniteAndBounded() throws {
        var engine = AimingEngine()
        var camera = forward
        let settings = AimSettings(enabled: true, targetPoint: .head, fovDegrees: 180)
        var commands = 0
        var maxStep = 0.0
        _ = engine.update(frame: frame(1, at: 0, candidates: [target(degrees: 0)]), settings: settings, at: 0)
        // Ten simulated minutes at 120 Hz, with target loss every second.
        for tick in 1...72000 {
            let time = Double(tick) / 120
            let candidates = tick % 120 < 10 ? [] : [target(degrees: 25 * sin(time))]
            let decision = engine.update(frame: frame(UInt64(tick + 1), at: time, candidates: candidates, forward: camera), settings: settings, at: time)
            if let command = decision.command {
                XCTAssertTrue(command.direction.isFinite)
                let step = try XCTUnwrap(camera.angleDegrees(to: command.direction))
                maxStep = max(maxStep, step)
                XCTAssertLessThanOrEqual(step, 1.500001)
                camera = command.direction; commands += 1
            } else { XCTAssertTrue(candidates.isEmpty) }
        }
        XCTAssertEqual(commands, 66000)
        print("Synthetic tracking: 72000 frames, 66000 commands, max angular step \(maxStep) degrees; not Free Fire gameplay.")
    }

    func testLargeFiniteCoordinatesNormalizeWithoutOverflow() throws {
        let vector = try XCTUnwrap(AimVector(1e300, 1e300, 1e300).normalized())
        XCTAssertEqual(vector.dot(vector), 1, accuracy: 1e-12)
    }
}
