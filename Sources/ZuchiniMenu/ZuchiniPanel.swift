#if canImport(SwiftUI)
import SwiftUI
import ZuchiniCore

@MainActor
public struct ZuchiniPanel: View {
    @ObservedObject private var store: MenuStore
    @State private var expandedChoiceID: String?
    private let theme: MenuTheme
    private var card: Color { Color(red: 0.10, green: 0.13, blue: 0.16) }

    public init(store: MenuStore, theme: MenuTheme = MenuTheme()) {
        self.store = store
        self.theme = theme
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(theme.text.opacity(0.07)).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !store.definition.subtitle.isEmpty {
                        Text(store.definition.subtitle)
                            .font(.footnote).foregroundStyle(theme.secondaryText)
                    }
                    if store.definition.sections.count > 1 { sectionPicker }
                    if let section = store.definition.sections.first(where: { $0.id == store.selectedSectionID }) {
                        ForEach(section.controls) { control in controlView(control) }
                    }
                }
                .padding(14)
            }
        }
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(theme.text.opacity(0.09), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.4), radius: 30, y: 12)
        .foregroundStyle(theme.text)
        .font(.subheadline)
        .tint(theme.accent)
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(store.definition.title) menu")
        .accessibilityAction(.escape) { store.dismiss() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "scope").font(.system(size: 18))
            Text(store.definition.title).font(.headline.weight(.medium))
            Spacer(minLength: 0)
            Button { store.dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 18, weight: .regular))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close menu")
            .accessibilityIdentifier("zuchini.close")
        }
        .foregroundStyle(theme.accent)
        .padding(.leading, 16).padding(.trailing, 6).padding(.vertical, 4)
    }

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.definition.sections) { section in
                    Button {
                        expandedChoiceID = nil
                        store.select(sectionID: section.id)
                    } label: {
                        Text(section.title).padding(.horizontal, 14).frame(minHeight: 44)
                            .foregroundStyle(store.selectedSectionID == section.id ? theme.accent : theme.secondaryText)
                            .background(card, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func controlView(_ control: MenuControl) -> some View {
        switch control.kind {
        case .toggle:
            Toggle(isOn: Binding(
                get: { store.toggleValue(for: control.id) },
                set: { store.set(.toggle($0), for: control.id) }
            )) { controlLabel(control) }
            .toggleStyle(CheckToggleStyle(accent: theme.accent, surface: theme.surface))
            .padding(10).background(card, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("zuchini.control.\(control.id)")
        case let .choice(options, _):
            VStack(alignment: .leading, spacing: 10) {
                controlLabel(control)
                Button {
                    expandedChoiceID = expandedChoiceID == control.id ? nil : control.id
                } label: {
                    HStack {
                        Text(store.choiceValue(for: control.id))
                        Spacer()
                        Image(systemName: expandedChoiceID == control.id ? "chevron.up" : "chevron.down")
                            .foregroundStyle(theme.accent).font(.subheadline)
                    }
                    .padding(.horizontal, 12).frame(minHeight: 44)
                    .background(card, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(control.title)
                .accessibilityValue(store.choiceValue(for: control.id))
                .accessibilityHint(expandedChoiceID == control.id ? "Collapse options" : "Expand options")
                .accessibilityIdentifier("zuchini.control.\(control.id)")
                if expandedChoiceID == control.id {
                    VStack(spacing: 4) {
                        ForEach(options, id: \.self) { option in
                            let selected = store.choiceValue(for: control.id) == option
                            Button {
                                store.set(.choice(option), for: control.id)
                                expandedChoiceID = nil
                            } label: {
                                HStack {
                                    Text(option)
                                    Spacer()
                                    if selected { Image(systemName: "checkmark") }
                                }
                                .foregroundStyle(selected ? theme.accent : theme.text)
                                .padding(.horizontal, 12).frame(minHeight: 44)
                                .background(selected ? theme.accent.opacity(0.15) : Color.clear,
                                            in: RoundedRectangle(cornerRadius: 10))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selected ? .isSelected : [])
                            .accessibilityIdentifier("zuchini.option.\(control.id).\(option)")
                        }
                    }
                    .padding(6).background(card, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        case let .slider(range, step, _):
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    controlLabel(control)
                    Spacer(minLength: 8)
                    Text(store.numberValue(for: control.id), format: .number.precision(.fractionLength(step < 1 ? 2 : 0)))
                        .monospacedDigit().foregroundStyle(theme.accent)
                }
                Slider(value: Binding(
                    get: { store.numberValue(for: control.id) },
                    set: { store.set(.number($0), for: control.id) }
                ), in: range, step: step)
                .accessibilityLabel(control.title)
                .accessibilityHint(control.detail)
                .accessibilityIdentifier("zuchini.control.\(control.id)")
            }
            .padding(12).background(card, in: RoundedRectangle(cornerRadius: 12))
        case .action:
            Button { store.perform(id: control.id) } label: {
                controlLabel(control).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(10).background(card, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("zuchini.control.\(control.id)")
        }
    }

    private func controlLabel(_ control: MenuControl) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(control.title).font(.subheadline)
            if !control.detail.isEmpty {
                Text(control.detail).font(.caption).foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct CheckToggleStyle: ToggleStyle {
    let accent: Color
    let surface: Color

    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack {
                configuration.label
                Spacer(minLength: 12)
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isOn ? accent : surface)
                    .frame(width: 28, height: 28)
                    .overlay {
                        if configuration.isOn {
                            Image(systemName: "checkmark").foregroundStyle(.white)
                        }
                    }
            }
            .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
        .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }
}
#endif
