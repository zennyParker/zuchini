#if canImport(SwiftUI)
import SwiftUI
import ZuchiniCore

@MainActor
public struct ZuchiniPanel: View {
    @ObservedObject private var store: MenuStore
    private let theme: MenuTheme

    public init(store: MenuStore, theme: MenuTheme = MenuTheme()) {
        self.store = store
        self.theme = theme
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                sectionPicker
                if let section = store.definition.sections.first(where: { $0.id == store.selectedSectionID }) {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(section.controls) { control in
                            controlView(control)
                            if control.id != section.controls.last?.id {
                                Rectangle().fill(theme.text.opacity(0.09)).frame(height: 1)
                            }
                        }
                    }
                }
                Button {
                    store.reset()
                } label: {
                    Label("Restore defaults", systemImage: "arrow.counterclockwise")
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(theme.secondaryText)
                .padding(.vertical, 8)
            }
            .padding(20)
        }
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(theme.text.opacity(0.12), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .foregroundStyle(theme.text)
        .tint(theme.accent)
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(store.definition.title) menu")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(store.definition.title).font(.title3.bold())
                if !store.definition.subtitle.isEmpty {
                    Text(store.definition.subtitle)
                        .font(.caption).foregroundStyle(theme.secondaryText)
                }
            }
            Spacer(minLength: 0)
            Button { store.dismiss() } label: {
                Image(systemName: "xmark").font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(theme.text.opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close menu")
        }
    }

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.definition.sections) { section in
                    let selected = store.selectedSectionID == section.id
                    Button { store.select(sectionID: section.id) } label: {
                        Text(section.title).font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14).frame(minHeight: 44)
                            .foregroundStyle(selected ? theme.surface : theme.secondaryText)
                            .background(selected ? theme.accent : theme.text.opacity(0.06), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
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
            .accessibilityIdentifier("zuchini.control.\(control.id)")
        case let .slider(range, step, _):
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    controlLabel(control)
                    Spacer(minLength: 8)
                    Text(store.numberValue(for: control.id), format: .number.precision(.fractionLength(0...2)))
                        .font(.subheadline.monospacedDigit()).foregroundStyle(theme.accent)
                }
                Slider(value: Binding(
                    get: { store.numberValue(for: control.id) },
                    set: { store.set(.number($0), for: control.id) }
                ), in: range, step: step)
                .accessibilityLabel(control.title)
                .accessibilityHint(control.detail)
                .accessibilityIdentifier("zuchini.control.\(control.id)")
            }
        case .action:
            Button { store.perform(id: control.id) } label: {
                HStack {
                    controlLabel(control)
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.right").foregroundStyle(theme.accent)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("zuchini.control.\(control.id)")
        }
    }

    private func controlLabel(_ control: MenuControl) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(control.title).font(.subheadline.weight(.semibold))
            if !control.detail.isEmpty {
                Text(control.detail).font(.caption).foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
#endif
