import Foundation

public enum MenuValue: Equatable, Sendable {
    case toggle(Bool)
    case number(Double)
    case choice(String)
}

/// Session-only state. This layer has no network, filesystem, or platform hooks.
public struct MenuState: Equatable, Sendable {
    public let definition: MenuDefinition
    public private(set) var values: [String: MenuValue] = [:]

    public init(definition: MenuDefinition) {
        self.definition = definition
        reset()
    }

    public func value(for id: String) -> MenuValue? { values[id] }

    /// Rejects unknown IDs, type mismatches, and nonfinite numbers.
    /// A false result also indicates an unchanged value (no duplicate UI event).
    @discardableResult
    public mutating func set(_ value: MenuValue, for id: String) -> Bool {
        guard let control = definition.control(id: id) else { return false }
        let next: MenuValue
        switch (control.kind, value) {
        case (.toggle, .toggle):
            next = value
        case let (.slider(range, step, _), .number(number)):
            guard number.isFinite else { return false }
            next = .number(Self.normalized(number, range: range, step: step))
        case let (.choice(options, _), .choice(selection)):
            guard options.contains(selection) else { return false }
            next = value
        default:
            return false
        }
        guard values[id] != next else { return false }
        values[id] = next
        return true
    }

    public mutating func reset() {
        values.removeAll(keepingCapacity: true)
        for control in definition.sections.flatMap(\.controls) {
            switch control.kind {
            case let .toggle(value): values[control.id] = .toggle(value)
            case let .slider(range, step, value):
                values[control.id] = .number(Self.normalized(value, range: range, step: step))
            case .action: break
            case let .choice(_, value): values[control.id] = .choice(value)
            }
        }
    }

    private static func normalized(_ value: Double, range: ClosedRange<Double>, step: Double) -> Double {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        let units = ((clamped - range.lowerBound) / step).rounded()
        return min(max(range.lowerBound + units * step, range.lowerBound), range.upperBound)
    }
}
