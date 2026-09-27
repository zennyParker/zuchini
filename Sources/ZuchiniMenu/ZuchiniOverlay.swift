#if canImport(SwiftUI)
import SwiftUI
import ZuchiniCore

/// Wrap content belonging to the host app. This creates no additional UIWindow.
@MainActor
public struct ZuchiniOverlay<Content: View>: View {
    @ObservedObject private var store: MenuStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let theme: MenuTheme
    private let content: Content
    private let onLauncherFrameChange: (CGRect) -> Void
    @State private var placement = LauncherPlacement()
    @GestureState private var dragOffset = CGSize.zero

    public init(store: MenuStore, theme: MenuTheme = MenuTheme(),
                onLauncherFrameChange: @escaping (CGRect) -> Void = { _ in },
                @ViewBuilder content: () -> Content) {
        self.store = store
        self.theme = theme
        self.content = content()
        self.onLauncherFrameChange = onLauncherFrameChange
    }

    public var body: some View {
        ZStack {
            content.accessibilityHidden(store.isPresented)
            if store.isPresented {
                Color.black.opacity(0.30)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { store.dismiss() }
                    .accessibilityHidden(true)
            }
            GeometryReader { geometry in
                if store.isPresented {
                    ZuchiniPanel(store: store, theme: theme)
                        .frame(width: min(theme.panelWidth, max(1, geometry.size.width - 24)),
                               height: min(360, max(1, geometry.size.height - 16)))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                } else {
                    let base = placement.center(width: geometry.size.width, height: geometry.size.height)
                    let center = draggedCenter(base: base, size: geometry.size)
                    Button {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
                            store.present()
                        }
                    } label: {
                        Image(systemName: "scope").font(.system(size: 20))
                            .foregroundStyle(theme.accent)
                            .frame(width: 44, height: 44)
                            .background(theme.surface, in: RoundedRectangle(cornerRadius: 12))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12).strokeBorder(theme.accent.opacity(0.5))
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open Zucchini menu")
                    .accessibilityHint("Drag to move the button")
                    .accessibilityIdentifier("zuchini.launcher")
                    .background {
                        GeometryReader { button in
                            Color.clear.preference(key: LauncherFrameKey.self, value: button.frame(in: .global))
                        }
                    }
                    .position(x: center.x, y: center.y)
                    .highPriorityGesture(DragGesture(minimumDistance: 6)
                        .updating($dragOffset) { value, state, _ in state = value.translation }
                        .onEnded { value in
                            placement.move(x: base.x + value.translation.width, y: base.y + value.translation.height,
                                           width: geometry.size.width, height: geometry.size.height)
                        })
                    .accessibilityAction(named: Text("Move left")) { move(dx: -60, dy: 0, size: geometry.size) }
                    .accessibilityAction(named: Text("Move right")) { move(dx: 60, dy: 0, size: geometry.size) }
                    .accessibilityAction(named: Text("Move up")) { move(dx: 0, dy: -60, size: geometry.size) }
                    .accessibilityAction(named: Text("Move down")) { move(dx: 0, dy: 60, size: geometry.size) }
                }
            }
        }
        .onPreferenceChange(LauncherFrameKey.self, perform: onLauncherFrameChange)
        .onChange(of: scenePhase) { phase in
            if phase != .active { store.dismiss() }
        }
        .onDisappear { store.dismiss() }
    }

    private func draggedCenter(base: (x: Double, y: Double), size: CGSize) -> (x: Double, y: Double) {
        var moved = placement
        moved.move(x: base.x + dragOffset.width, y: base.y + dragOffset.height, width: size.width, height: size.height)
        return moved.center(width: size.width, height: size.height)
    }

    private func move(dx: Double, dy: Double, size: CGSize) {
        let base = placement.center(width: size.width, height: size.height)
        placement.move(x: base.x + dx, y: base.y + dy, width: size.width, height: size.height)
    }
}

private struct LauncherFrameKey: PreferenceKey {
    static var defaultValue: CGRect { .zero }
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}
#endif
