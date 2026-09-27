import XCTest
@testable import ZuchiniCore

final class MenuStateTests: XCTestCase {
    private func definition() throws -> MenuDefinition {
        try MenuDefinition(title: "Test", sections: [
            MenuSection(id: "main", title: "Main", controls: [
                MenuControl(id: "grid", title: "Grid", kind: .toggle(defaultValue: false)),
                MenuControl(id: "level", title: "Level", kind: .slider(range: 10...100, step: 5, defaultValue: 70)),
                MenuControl(id: "reset", title: "Reset", kind: .action)
            ])
        ])
    }

    func testOutOfRangeAndOffStepValuesAreNormalized() throws {
        var state = MenuState(definition: try definition())
        XCTAssertTrue(state.set(.number(109), for: "level"))
        XCTAssertEqual(state.value(for: "level"), .number(100))
        XCTAssertTrue(state.set(.number(-500), for: "level"))
        XCTAssertEqual(state.value(for: "level"), .number(10))
        XCTAssertTrue(state.set(.number(73), for: "level"))
        XCTAssertEqual(state.value(for: "level"), .number(75))
        XCTAssertFalse(state.set(.number(74), for: "level"))
    }

    func testUnknownMismatchedAndNonfiniteInputsDoNotChangeState() throws {
        var state = MenuState(definition: try definition())
        let before = state
        XCTAssertFalse(state.set(.toggle(true), for: "unknown"))
        XCTAssertFalse(state.set(.number(1), for: "grid"))
        XCTAssertFalse(state.set(.toggle(true), for: "level"))
        XCTAssertFalse(state.set(.number(.nan), for: "level"))
        XCTAssertFalse(state.set(.number(.infinity), for: "level"))
        XCTAssertFalse(state.set(.toggle(true), for: "reset"))
        XCTAssertEqual(state, before)
    }

    func testResetRestoresDefaultsWithoutAddingActionState() throws {
        var state = MenuState(definition: try definition())
        state.set(.toggle(true), for: "grid")
        state.set(.number(95), for: "level")
        state.reset()
        XCTAssertEqual(state.value(for: "grid"), .toggle(false))
        XCTAssertEqual(state.value(for: "level"), .number(70))
        XCTAssertNil(state.value(for: "reset"))
    }

    func testControlIDsMustBeUniqueAcrossSections() {
        let control = MenuControl(id: "same", title: "Toggle", kind: .toggle(defaultValue: true))
        XCTAssertThrowsError(try MenuDefinition(title: "Bad", sections: [
            MenuSection(id: "a", title: "A", controls: [control]),
            MenuSection(id: "b", title: "B", controls: [control])
        ])) { error in
            XCTAssertEqual(error as? MenuDefinitionError, .duplicateControl("same"))
        }
    }

    func testRejectsSliderConfigurationThatCannotBeRendered() {
        for step in [0.0, -1.0, Double.infinity, Double.nan, 200.0] {
            XCTAssertThrowsError(try MenuDefinition(title: "Bad", sections: [
                MenuSection(id: "s", title: "S", controls: [
                    MenuControl(id: "v", title: "V", kind: .slider(range: 0...100, step: step, defaultValue: 50))
                ])
            ]))
        }
    }

    func testRejectsEmptyMenuAndDuplicateSections() {
        XCTAssertThrowsError(try MenuDefinition(title: "Empty", sections: []))
        let section = MenuSection(id: "s", title: "S", controls: [
            MenuControl(id: "b", title: "B", kind: .action)
        ])
        XCTAssertThrowsError(try MenuDefinition(title: "Duplicate", sections: [section, section])) { error in
            XCTAssertEqual(error as? MenuDefinitionError, .duplicateSection("s"))
        }
    }

    func testIndependentScenesDoNotShareState() throws {
        let definition = try definition()
        var first = MenuState(definition: definition)
        let second = MenuState(definition: definition)
        first.set(.toggle(true), for: "grid")
        XCTAssertEqual(second.value(for: "grid"), .toggle(false))
    }
}
