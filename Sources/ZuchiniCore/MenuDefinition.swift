import Foundation

public struct MenuControl: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case toggle(defaultValue: Bool)
        case slider(range: ClosedRange<Double>, step: Double, defaultValue: Double)
        case choice(options: [String], defaultValue: String)
        case action
    }

    public let id: String
    public let title: String
    public let detail: String
    public let kind: Kind

    public init(id: String, title: String, detail: String = "", kind: Kind) {
        self.id = id
        self.title = title
        self.detail = detail
        self.kind = kind
    }
}

public struct MenuSection: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let controls: [MenuControl]

    public init(id: String, title: String, controls: [MenuControl]) {
        self.id = id
        self.title = title
        self.controls = controls
    }
}

public enum MenuDefinitionError: Error, Equatable {
    case emptyTitle
    case missingSections
    case invalidSection(String)
    case duplicateSection(String)
    case invalidControl(String)
    case duplicateControl(String)
    case invalidSlider(String)
    case invalidChoice(String)
}

/// Immutable, validated menu structure. IDs are stable host-facing identifiers.
public struct MenuDefinition: Equatable, Sendable {
    public let title: String
    public let subtitle: String
    public let sections: [MenuSection]

    public init(title: String, subtitle: String = "", sections: [MenuSection]) throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MenuDefinitionError.emptyTitle
        }
        guard !sections.isEmpty else { throw MenuDefinitionError.missingSections }
        var sectionIDs = Set<String>()
        var controlIDs = Set<String>()
        for section in sections {
            guard !section.id.isEmpty, !section.title.isEmpty, !section.controls.isEmpty else {
                throw MenuDefinitionError.invalidSection(section.id)
            }
            guard sectionIDs.insert(section.id).inserted else {
                throw MenuDefinitionError.duplicateSection(section.id)
            }
            for control in section.controls {
                guard !control.id.isEmpty, !control.title.isEmpty else {
                    throw MenuDefinitionError.invalidControl(control.id)
                }
                guard controlIDs.insert(control.id).inserted else {
                    throw MenuDefinitionError.duplicateControl(control.id)
                }
                if case let .slider(range, step, value) = control.kind {
                    let span = range.upperBound - range.lowerBound
                    guard range.lowerBound.isFinite, range.upperBound.isFinite,
                          span.isFinite, span > 0, step.isFinite, step > 0,
                          step <= span, (span / step).isFinite, value.isFinite else {
                        throw MenuDefinitionError.invalidSlider(control.id)
                    }
                }
                if case let .choice(options, value) = control.kind {
                    guard !options.isEmpty, Set(options).count == options.count,
                          options.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
                          options.contains(value) else {
                        throw MenuDefinitionError.invalidChoice(control.id)
                    }
                }
            }
        }
        self.title = title
        self.subtitle = subtitle
        self.sections = sections
    }

    public func control(id: String) -> MenuControl? {
        sections.lazy.flatMap(\.controls).first { $0.id == id }
    }
}
