import SwiftUI
import ZuchiniCore
import ZuchiniMenu

@main
@MainActor
struct ZuchiniDemoApp: App {
    var body: some Scene {
        WindowGroup {
            DemoRoot()
        }
    }
}

@MainActor
private struct DemoRoot: View {
    @StateObject private var store: MenuStore
    @State private var tapCount = 0
    @State private var lastAction = "Ready"

    init() {
        do {
            let definition = try MenuDefinition(title: "Zuchini", subtitle: "Your local control panel", sections: [
                MenuSection(id: "scene", title: "Scene", controls: [
                    MenuControl(id: "grid", title: "Guide grid", detail: "Show a grid on this demo canvas.", kind: .toggle(defaultValue: false)),
                    MenuControl(id: "brightness", title: "Scene brightness", detail: "Change the demo background.", kind: .slider(range: 20...100, step: 5, defaultValue: 70)),
                    MenuControl(id: "center", title: "Reset canvas counter", detail: "Run an action in the demo app.", kind: .action)
                ]),
                MenuSection(id: "display", title: "Display", controls: [
                    MenuControl(id: "guidance", title: "Show guidance", detail: "Keep the canvas instructions visible.", kind: .toggle(defaultValue: true)),
                    MenuControl(id: "marker", title: "Marker size", detail: "Adjust the demo marker diameter.", kind: .slider(range: 40...100, step: 5, defaultValue: 64))
                ])
            ])
            _store = StateObject(wrappedValue: MenuStore(definition: definition))
        } catch {
            // A configuration error in this source file, never a key/auth failure.
            preconditionFailure("Invalid demo menu definition: \(error)")
        }
    }

    var body: some View {
        ZuchiniOverlay(store: store) {
            GeometryReader { geometry in
                ZStack {
                    Color(red: 0.035, green: 0.065, blue: 0.055).ignoresSafeArea()
                    LinearGradient(
                        colors: [.green.opacity(store.numberValue(for: "brightness") / 400), .clear],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ).ignoresSafeArea()
                    if store.toggleValue(for: "grid") {
                        Path { path in
                            for x in stride(from: CGFloat.zero, through: geometry.size.width, by: 32) {
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                            }
                            for y in stride(from: CGFloat.zero, through: geometry.size.height, by: 32) {
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                            }
                        }
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                        .allowsHitTesting(false)
                    }
                    VStack(spacing: 20) {
                        Text("ZUCHINI / PLAYGROUND")
                            .font(.caption.monospaced().weight(.medium)).tracking(2)
                            .foregroundStyle(.white.opacity(0.6))
                        Circle()
                            .fill(Color(red: 0.74, green: 0.94, blue: 0.34))
                            .frame(width: store.numberValue(for: "marker"), height: store.numberValue(for: "marker"))
                            .overlay { Image(systemName: "leaf.fill").foregroundStyle(.black.opacity(0.7)) }
                        Text("Make it yours.").font(.largeTitle.bold())
                        if store.toggleValue(for: "guidance") {
                            Text("Open Z to explore the controls.\nEvery change stays on this canvas.")
                                .font(.subheadline).multilineTextAlignment(.center)
                                .foregroundStyle(.white.opacity(0.68))
                        }
                        Button("Canvas taps: \(tapCount)") { tapCount += 1 }
                            .buttonStyle(.bordered).tint(.white)
                            .accessibilityIdentifier("demo.canvasCounter")
                        Text(lastAction).font(.caption).foregroundStyle(.white.opacity(0.55))
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .foregroundStyle(.white)
        }
        .onAppear {
            let countBinding = $tapCount
            let actionBinding = $lastAction
            store.onEvent = { event in
                switch event {
                case .action(id: "center"):
                    countBinding.wrappedValue = 0
                    actionBinding.wrappedValue = "Canvas counter reset"
                case .reset:
                    actionBinding.wrappedValue = "Default controls restored"
                default: break
                }
            }
        }
        .onDisappear { store.onEvent = nil }
    }
}
