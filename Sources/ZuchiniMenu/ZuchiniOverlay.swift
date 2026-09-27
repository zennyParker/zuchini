#if canImport(SwiftUI)
import SwiftUI

/// Wrap content belonging to your own app. This creates no additional UIWindow.
@MainActor
public struct ZuchiniOverlay<Content: View>: View {
    @ObservedObject private var store: MenuStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let theme: MenuTheme
    private let content: Content

    public init(store: MenuStore, theme: MenuTheme = MenuTheme(), @ViewBuilder content: () -> Content) {
        self.store = store
        self.theme = theme
        self.content = content()
    }

    public var body: some View {
        ZStack {
            content
                .accessibilityHidden(store.isPresented)
            if store.isPresented {
                Color.black.opacity(0.30)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { store.dismiss() }
                    .accessibilityHidden(true)
            }
            GeometryReader { geometry in
                VStack(alignment: .trailing, spacing: 12) {
                    Button {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
                            store.togglePresentation()
                        }
                    } label: {
                        Text("Z").font(.title3.weight(.black))
                            .foregroundStyle(theme.surface)
                            .frame(width: 48, height: 48)
                            .background(theme.accent, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(store.isPresented ? "Close Zuchini menu" : "Open Zuchini menu")
                    .accessibilityIdentifier("zuchini.launcher")

                    if store.isPresented {
                        ZuchiniPanel(store: store, theme: theme)
                            .frame(width: min(theme.panelWidth, max(1, geometry.size.width - 24)))
                            .frame(maxHeight: max(1, geometry.size.height - 84))
                            .transition(.opacity)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { store.dismiss() }
        }
        .onDisappear { store.dismiss() }
    }
}
#endif
