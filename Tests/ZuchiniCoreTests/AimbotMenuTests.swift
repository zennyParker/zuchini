import XCTest
@testable import ZuchiniCore

final class AimbotMenuTests: XCTestCase {
    func testTargetSelectionRejectsUnsupportedChoicesAndResets() throws {
        var state = MenuState(definition: try AimbotMenu.definition())
        XCTAssertEqual(state.value(for: "aimbot.target"), .choice("Neck"))
        XCTAssertTrue(state.set(.choice("Head"), for: "aimbot.target"))
        XCTAssertFalse(state.set(.choice("Chest"), for: "aimbot.target"))
        XCTAssertFalse(state.set(.choice("Randomized"), for: "aimbot.target"))
        XCTAssertFalse(state.set(.number(1), for: "aimbot.target"))
        XCTAssertFalse(state.set(.choice("Head"), for: "aimbot.enabled"))
        XCTAssertEqual(state.value(for: "aimbot.target"), .choice("Head"))
        state.reset()
        XCTAssertEqual(state.value(for: "aimbot.target"), .choice("Neck"))
    }

    func testChoiceSchemaRejectsEmptyDuplicateAndMissingDefaults() {
        for (options, value) in [([], "Head"), (["Head", "Head"], "Head"),
                                 (["Head", " "], "Head"), (["Head", "Neck"], "Chest")] {
            XCTAssertThrowsError(try MenuDefinition(title: "Test", sections: [
                MenuSection(id: "main", title: "Main", controls: [
                    MenuControl(id: "target", title: "Target", kind: .choice(options: options, defaultValue: value))
                ])
            ])) { error in
                XCTAssertEqual(error as? MenuDefinitionError, .invalidChoice("target"))
            }
        }
    }

    func testAimbotControlsHaveBoundedValuesAndIndependentSessionState() throws {
        let definition = try AimbotMenu.definition()
        var state = MenuState(definition: definition)
        let other = MenuState(definition: definition)
        XCTAssertEqual(state.value(for: "aimbot.enabled"), .toggle(false))
        XCTAssertEqual(state.value(for: "aimbot.fov"), .number(60))
        state.set(.toggle(true), for: "aimbot.enabled")
        state.set(.number(999), for: "aimbot.fov")
        XCTAssertEqual(state.value(for: "aimbot.fov"), .number(180))
        state.set(.number(-1), for: "aimbot.fov")
        XCTAssertEqual(state.value(for: "aimbot.fov"), .number(1))
        state.set(.toggle(false), for: "aimbot.enabled")
        XCTAssertEqual(state.value(for: "aimbot.enabled"), .toggle(false))
        XCTAssertEqual(other.value(for: "aimbot.enabled"), .toggle(false))
        XCTAssertFalse(state.set(.number(.nan), for: "aimbot.fov"))
    }
}
