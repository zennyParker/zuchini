#if canImport(SwiftUI)
import SwiftUI

/// Wrap content belonging to the host app. This creates no additional UIWindow.
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
                               height: min(550, max(1, geometry.size.height - 24)))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                } else {
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
                                    store.present()
                                }
                            } label: {
                                Image(systemName: "scope").font(.title2)
                                    .foregroundStyle(theme.accent)
                                    .frame(width: 48, height: 48)
                                    .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14).strokeBorder(theme.accent.opacity(0.5))
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open Zucchini menu")
                            .accessibilityIdentifier("zuchini.launcher")
                        }
                        Spacer()
                    }
                    .padding(12)
                }
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { store.dismiss() }
        }
        .onDisappear { store.dismiss() }
    }
}
#endif
