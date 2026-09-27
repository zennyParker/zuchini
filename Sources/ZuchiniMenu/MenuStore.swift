#if canImport(SwiftUI)
import SwiftUI
import ZuchiniCore

public enum MenuEvent: Equatable, Sendable {
    case valueChanged(id: String, value: MenuValue)
    case action(id: String)
    case reset
}

/// One store per scene/host. Keep event handlers short; start host-owned async
/// work if needed instead of blocking UI callbacks.
@MainActor
public final class MenuStore: ObservableObject {
    @Published public private(set) var state: MenuState
    @Published public private(set) var isPresented = false
    @Published public private(set) var selectedSectionID: String
    public var onEvent: ((MenuEvent) -> Void)?

    public var definition: MenuDefinition { state.definition }

    public init(definition: MenuDefinition, onEvent: ((MenuEvent) -> Void)? = nil) {
        state = MenuState(definition: definition)
        selectedSectionID = definition.sections[0].id
        self.onEvent = onEvent
    }

    public func present() { isPresented = true }
    public func dismiss() { isPresented = false }
    public func togglePresentation() { isPresented.toggle() }

    public func select(sectionID: String) {
        guard definition.sections.contains(where: { $0.id == sectionID }) else { return }
        selectedSectionID = sectionID
    }

    public func set(_ value: MenuValue, for id: String) {
        var next = state
        guard next.set(value, for: id), let actual = next.value(for: id) else { return }
        state = next
        onEvent?(.valueChanged(id: id, value: actual))
    }

    public func perform(id: String) {
        guard definition.control(id: id)?.kind == .action else { return }
        onEvent?(.action(id: id))
    }

    public func reset() {
        var next = state
        next.reset()
        state = next
        onEvent?(.reset)
    }

    public func toggleValue(for id: String) -> Bool {
        guard case let .toggle(value)? = state.value(for: id) else { return false }
        return value
    }

    public func numberValue(for id: String) -> Double {
        guard case let .number(value)? = state.value(for: id) else { return 0 }
        return value
    }

    public func choiceValue(for id: String) -> String {
        guard case let .choice(value)? = state.value(for: id) else { return "" }
        return value
    }
}
#endif
